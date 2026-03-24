//  AssetFlow — snapshot-based portfolio management for macOS.
//  Copyright (C) 2026 Jen-Chien Chang
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import SwiftData

@Observable
@MainActor
final class BulkEntryViewModel {

  var snapshotDate: Date
  var rows: [BulkEntryRow]
  var savedSnapshot: Snapshot?

  private let modelContext: ModelContext

  var platformGroups: [(platform: String, rows: [BulkEntryRow])] {
    let grouped = Dictionary(grouping: rows, by: \.platform)
    return grouped.keys.sorted().map { platform in
      (platform: platform, rows: (grouped[platform] ?? []).sorted { $0.assetName < $1.assetName })
    }
  }

  var updatedCount: Int { rows.filter(\.isUpdated).count }
  var pendingCount: Int { rows.filter(\.isPending).count }
  var excludedCount: Int { rows.filter { !$0.isIncluded }.count }
  var includedCount: Int { rows.filter(\.isIncluded).count }
  var zeroValueCount: Int { rows.filter(\.hasZeroValueError).count }
  var hasInvalidNewRows: Bool {
    rows.contains { $0.isIncluded && $0.hasEmptyName }
  }
  var duplicateNameRowIDs: Set<UUID> {
    var duplicateIDs = Set<UUID>()
    for (_, groupRows) in Dictionary(grouping: rows.filter(\.isIncluded), by: \.platform) {
      var seen = [String: UUID]()
      for row in groupRows {
        let key = row.assetName.normalizedForIdentity
        guard !key.isEmpty else { continue }
        if let existingID = seen[key] {
          duplicateIDs.insert(existingID)
          duplicateIDs.insert(row.id)
        } else {
          seen[key] = row.id
        }
      }
    }
    return duplicateIDs
  }
  var hasDuplicateNames: Bool { !duplicateNameRowIDs.isEmpty }

  // MARK: - Column Mapping State

  var showColumnMappingSheet: Bool = false
  var pendingRawHeaders: [String] = []
  var pendingSampleRows: [[String]] = []
  var pendingPartialMapping: [CanonicalColumn: Int] = [:]
  var pendingCSVData: Data?
  var pendingCSVPlatform: String = ""
  var lastImportResult: CSVImportResult?
  var canSave: Bool {
    includedCount > 0 && zeroValueCount == 0 && !hasInvalidNewRows && !hasDuplicateNames
      && !rows.contains(where: { $0.isIncluded && $0.hasValidationError })
  }
  var hasUnsavedChanges: Bool {
    rows.contains { !$0.newValueText.isEmpty }
      || rows.contains { !$0.isIncluded }
      || rows.contains { $0.source == .manualNew }
  }

  init(modelContext: ModelContext, date: Date) {
    self.modelContext = modelContext
    self.snapshotDate = Calendar.current.startOfDay(for: date)
    self.rows = []
    loadRowsFromLatestSnapshot()
  }

  func toggleInclude(rowID: UUID) {
    guard let index = rows.firstIndex(where: { $0.id == rowID }) else { return }
    rows[index].isIncluded.toggle()
    if !rows[index].isIncluded {
      rows[index].newValueText = ""
    }
  }

  @discardableResult
  func addManualRow(forPlatform platform: String) -> UUID {
    let row = BulkEntryRow(
      id: UUID(),
      asset: nil,
      assetName: "",
      platform: platform,
      currency: SettingsService.shared.mainCurrency,
      previousValue: nil,
      newValueText: "",
      isIncluded: true,
      source: .manualNew,
      categoryName: nil
    )
    rows.append(row)
    return row.id
  }

  @discardableResult
  func addPlatform(name: String) -> UUID? {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }
    let existing = Set(rows.map { $0.platform.normalizedForIdentity })
    guard !existing.contains(trimmed.normalizedForIdentity) else { return nil }
    return addManualRow(forPlatform: trimmed)
  }

  func removeManualRow(rowID: UUID) {
    rows.removeAll { $0.id == rowID && $0.source == .manualNew }
  }

  func saveSnapshot() throws -> Snapshot {
    let includedRows = rows.filter(\.isIncluded)
    guard !includedRows.isEmpty else {
      throw SnapshotError.noAssetsIncluded
    }

    // Guard against duplicate date (race condition: another snapshot may have
    // been created for this date while the user was editing values)
    let targetDate = snapshotDate
    var dateCheckDescriptor = FetchDescriptor<Snapshot>(
      predicate: #Predicate { $0.date == targetDate }
    )
    dateCheckDescriptor.fetchLimit = 1
    if ((try? modelContext.fetch(dateCheckDescriptor)) ?? []).first != nil {
      throw SnapshotError.dateAlreadyExists(snapshotDate)
    }

    let snapshot = Snapshot(date: snapshotDate)
    modelContext.insert(snapshot)

    for row in includedRows {
      let asset: Asset
      if let existingAsset = row.asset {
        asset = existingAsset
      } else {
        asset = modelContext.findOrCreateAsset(
          name: row.assetName, platform: row.platform)
        asset.currency = row.currency
        if let categoryName = row.categoryName?.trimmingCharacters(in: .whitespaces),
          !categoryName.isEmpty
        {
          asset.category = modelContext.resolveCategory(name: categoryName)
        }
      }

      let marketValue = row.newValue ?? Decimal(0)
      let sav = SnapshotAssetValue(marketValue: marketValue)
      sav.snapshot = snapshot
      sav.asset = asset
      modelContext.insert(sav)
    }

    savedSnapshot = snapshot
    return snapshot
  }

  @discardableResult
  func importCSV(data: Data, forPlatform platform: String) -> CSVImportResult {
    // Parse without importPlatform override to get raw CSV platform/currency values
    let result = CSVParsingService.parseAssetCSV(data: data, importPlatform: nil)

    // Clear previous CSV values for this platform
    for index in rows.indices where rows[index].platform == platform && rows[index].source == .csv {
      if rows[index].asset != nil {
        rows[index].newValueText = ""
        rows[index].source = .manual
      }
    }
    rows.removeAll { $0.platform == platform && $0.source == .csv && $0.asset == nil }

    let errors = result.errors.map(\.message)
    let parserWarnings = result.warnings.map(\.message)
    let mainCurrency = SettingsService.shared.mainCurrency

    var matchedCount = 0
    var newCount = 0
    var platformMismatches: [String] = []
    var currencyMismatches: [String] = []

    for csvRow in result.rows {
      // Platform mismatch: CSV has a platform column value that differs from the target group
      if !csvRow.platform.isEmpty,
        csvRow.platform.normalizedForIdentity != platform.normalizedForIdentity
      {
        platformMismatches.append(csvRow.assetName)
        continue
      }

      let normalizedCSVName = csvRow.assetName.normalizedForIdentity
      if let index = rows.firstIndex(where: {
        $0.platform == platform && $0.assetName.normalizedForIdentity == normalizedCSVName
      }) {
        // Currency mismatch: CSV has a currency value that differs from the existing asset
        if !csvRow.currency.isEmpty,
          csvRow.currency.uppercased() != rows[index].currency.uppercased()
        {
          currencyMismatches.append(csvRow.assetName)
          continue
        }
        rows[index].newValueText = "\(csvRow.marketValue)"
        rows[index].source = .csv
        matchedCount += 1
      } else {
        let newRow = BulkEntryRow(
          id: UUID(),
          asset: nil,
          assetName: csvRow.assetName,
          platform: platform,
          currency: csvRow.currency.isEmpty ? mainCurrency : csvRow.currency,
          previousValue: nil,
          newValueText: "\(csvRow.marketValue)",
          isIncluded: true,
          source: .csv,
          // categoryName is intentionally nil: AssetCSVRow has no category field,
          // so CSVParsingService cannot provide one. Users assign categories in
          // SnapshotDetailView after saving.
          categoryName: nil
        )
        rows.append(newRow)
        newCount += 1
      }
    }

    return CSVImportResult(
      matchedCount: matchedCount,
      newCount: newCount,
      errors: errors,
      parserWarnings: parserWarnings,
      platformMismatches: platformMismatches,
      currencyMismatches: currencyMismatches
    )
  }

  // MARK: - Column Mapping

  /// Loads CSV data with auto-detection. Shows mapping sheet if headers don't match.
  ///
  /// If headers match, calls `importCSV` directly. Otherwise, populates
  /// mapping state and sets `showColumnMappingSheet = true`.
  func loadCSVForMapping(data: Data, forPlatform platform: String) {
    let headers = CSVParsingService.extractHeaders(from: data)

    // Empty/invalid files — import directly to get proper error reporting
    guard !headers.isEmpty else {
      _ = importCSV(data: data, forPlatform: platform)
      return
    }

    let detectResult = CSVParsingService.autoDetectMapping(
      headers: headers, schema: .assetWithoutPlatform)

    switch detectResult {
    case .matched:
      lastImportResult = importCSV(data: data, forPlatform: platform)

    case .needsUserMapping(let rawHeaders, let partialMap):
      pendingCSVData = data
      pendingCSVPlatform = platform
      pendingRawHeaders = rawHeaders
      pendingSampleRows = CSVParsingService.extractSampleRows(from: data)
      pendingPartialMapping = partialMap
      showColumnMappingSheet = true
    }
  }

  /// Confirms a user-provided column mapping and imports the pending CSV data.
  @discardableResult
  func confirmColumnMapping(_ mapping: CSVColumnMapping) -> CSVImportResult? {
    showColumnMappingSheet = false
    guard let data = pendingCSVData else { return nil }
    let platform = pendingCSVPlatform

    let remappedData = CSVParsingService.parseAssetCSV(
      data: data, mapping: mapping, importPlatform: nil)

    // Build a new CSV string with canonical headers from the mapped result,
    // then feed to the existing importCSV which handles matching/appending.
    // Instead, we directly process the parsed rows here.
    let result = importCSVFromParsedRows(remappedData, forPlatform: platform)
    lastImportResult = result

    pendingCSVData = nil
    pendingCSVPlatform = ""
    pendingRawHeaders = []
    pendingSampleRows = []
    pendingPartialMapping = [:]

    return result
  }

  /// Imports already-parsed CSV rows into the bulk entry rows.
  private func importCSVFromParsedRows(
    _ parseResult: CSVParseResult<AssetCSVRow>,
    forPlatform platform: String
  ) -> CSVImportResult {
    // Clear previous CSV values for this platform
    for index in rows.indices
    where rows[index].platform == platform && rows[index].source == .csv {
      if rows[index].asset != nil {
        rows[index].newValueText = ""
        rows[index].source = .manual
      }
    }
    rows.removeAll { $0.platform == platform && $0.source == .csv && $0.asset == nil }

    let errors = parseResult.errors.map(\.message)
    let parserWarnings = parseResult.warnings.map(\.message)
    let mainCurrency = SettingsService.shared.mainCurrency

    var matchedCount = 0
    var newCount = 0
    var platformMismatches: [String] = []
    var currencyMismatches: [String] = []

    for csvRow in parseResult.rows {
      if !csvRow.platform.isEmpty,
        csvRow.platform.normalizedForIdentity != platform.normalizedForIdentity
      {
        platformMismatches.append(csvRow.assetName)
        continue
      }

      let normalizedCSVName = csvRow.assetName.normalizedForIdentity
      if let index = rows.firstIndex(where: {
        $0.platform == platform && $0.assetName.normalizedForIdentity == normalizedCSVName
      }) {
        if !csvRow.currency.isEmpty,
          csvRow.currency.uppercased() != rows[index].currency.uppercased()
        {
          currencyMismatches.append(csvRow.assetName)
          continue
        }
        rows[index].newValueText = "\(csvRow.marketValue)"
        rows[index].source = .csv
        matchedCount += 1
      } else {
        let newRow = BulkEntryRow(
          id: UUID(),
          asset: nil,
          assetName: csvRow.assetName,
          platform: platform,
          currency: csvRow.currency.isEmpty ? mainCurrency : csvRow.currency,
          previousValue: nil,
          newValueText: "\(csvRow.marketValue)",
          isIncluded: true,
          source: .csv,
          categoryName: nil
        )
        rows.append(newRow)
        newCount += 1
      }
    }

    return CSVImportResult(
      matchedCount: matchedCount,
      newCount: newCount,
      errors: errors,
      parserWarnings: parserWarnings,
      platformMismatches: platformMismatches,
      currencyMismatches: currencyMismatches
    )
  }

  // MARK: - Private

  private func loadRowsFromLatestSnapshot() {
    let targetDate = snapshotDate
    let descriptor = FetchDescriptor<Snapshot>(
      sortBy: [SortDescriptor(\.date, order: .reverse)]
    )

    guard let allSnapshots = try? modelContext.fetch(descriptor),
      let latestBefore = allSnapshots.first(where: { $0.date < targetDate }),
      let assetValues = latestBefore.assetValues
    else { return }

    rows =
      assetValues.compactMap { sav in
        guard let asset = sav.asset else { return nil }
        // Intentionally uses asset.id (not UUID()) for stable identity across
        // SwiftUI re-renders. Collision with CSV-imported rows (which use UUID())
        // cannot occur because importCSV() matches by normalizedName within the
        // platform group before deciding match vs. new row.
        return BulkEntryRow(
          id: asset.id,
          asset: asset,
          assetName: asset.name,
          platform: asset.platform,
          currency: asset.currency,
          previousValue: sav.marketValue,
          newValueText: "",
          isIncluded: true,
          source: .manual,
          categoryName: nil
        )
      }.sorted { ($0.platform, $0.assetName) < ($1.platform, $1.assetName) }
  }
}
