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
  var cashFlowRows: [BulkEntryCashFlowRow] = []
  var savedSnapshot: Snapshot?
  var pendingFocusRowID: UUID?
  var pendingCashFlowFocusRowID: UUID?

  // MARK: - Cash Flow Column Mapping State

  var showCashFlowColumnMappingSheet: Bool = false
  var pendingCashFlowRawHeaders: [String] = []
  var pendingCashFlowSampleRows: [[String]] = []
  var pendingCashFlowPartialMapping: [CanonicalColumn: Int] = [:]
  var pendingCashFlowCSVData: Data?
  var lastCashFlowImportResult: CashFlowCSVImportResult?

  private let modelContext: ModelContext

  var platformGroups: [(platform: String, rows: [BulkEntryRow])] {
    let grouped = Dictionary(grouping: rows, by: \.platform)
    return grouped.keys.sorted().map { platform in
      (platform: platform, rows: grouped[platform] ?? [])
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

  var cashFlowCount: Int {
    cashFlowRows.filter(\.isIncluded).count
  }

  var includedCashFlowNetByCurrency: [(currency: String, total: Decimal)] {
    var totals: [String: Decimal] = [:]
    for row in cashFlowRows where row.isIncluded {
      guard let amount = row.amount else { continue }
      totals[row.currency, default: 0] += amount
    }
    return totals.sorted { $0.key < $1.key }.map { (currency: $0.key, total: $0.value) }
  }

  var hasEmptyCashFlowAmounts: Bool {
    cashFlowRows.contains(where: \.hasEmptyAmount)
  }

  var hasEmptyCashFlowDescriptions: Bool {
    cashFlowRows.contains { $0.isIncluded && $0.hasEmptyDescription }
  }

  var hasCashFlowValidationErrors: Bool {
    cashFlowRows.contains { $0.isIncluded && $0.hasValidationError }
  }

  // MARK: - Column Mapping State

  var showColumnMappingSheet: Bool = false
  var pendingRawHeaders: [String] = []
  var pendingSampleRows: [[String]] = []
  var pendingPartialMapping: [CanonicalColumn: Int] = [:]
  var pendingCSVData: Data?
  var pendingCSVPlatform: String = ""
  var lastImportResult: CSVImportResult?
  var canSave: Bool {
    var hasIncluded = false
    for row in rows {
      guard row.isIncluded else { continue }
      hasIncluded = true
      if row.hasZeroValueError || row.hasEmptyName || row.hasValidationError {
        return false
      }
    }
    guard hasIncluded else { return false }
    for cfRow in cashFlowRows {
      if cfRow.hasEmptyAmount { return false }
      guard cfRow.isIncluded else { continue }
      if cfRow.hasValidationError || cfRow.hasEmptyDescription { return false }
    }
    return true
  }
  var hasUnsavedChanges: Bool {
    rows.contains { !$0.newValueText.isEmpty }
      || rows.contains { !$0.isIncluded }
      || rows.contains { $0.source == .manualNew }
      || !cashFlowRows.isEmpty
  }

  init(modelContext: ModelContext, date: Date) {
    self.modelContext = modelContext
    self.snapshotDate = Calendar.current.startOfDay(for: date)
    self.rows = []
    loadRowsFromLatestSnapshot()
  }

  /// Returns the ID of the next included row in visual (platform-grouped) order
  /// after the row with the given ID, or `nil` if already at the last included row.
  func nextFocusRowID(after currentRowID: UUID) -> UUID? {
    var found = false
    for group in platformGroups {
      for row in group.rows where row.isIncluded {
        if found { return row.id }
        if row.id == currentRowID { found = true }
      }
    }
    return nil
  }

  func advanceFocus(from currentRowID: UUID) {
    pendingFocusRowID = nextFocusRowID(after: currentRowID)
  }

  func nextCashFlowFocusRowID(after currentRowID: UUID) -> UUID? {
    var found = false
    for row in cashFlowRows where row.isIncluded {
      if found { return row.id }
      if row.id == currentRowID { found = true }
    }
    return nil
  }

  func advanceCashFlowFocus(from currentRowID: UUID) {
    pendingCashFlowFocusRowID = nextCashFlowFocusRowID(after: currentRowID)
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

  // MARK: - Cash Flow Row Management

  @discardableResult
  func addManualCashFlowRow() -> UUID {
    let row = BulkEntryCashFlowRow(
      id: UUID(), cashFlowDescription: "", amountText: "",
      currency: SettingsService.shared.mainCurrency,
      isIncluded: true, source: .manualNew)
    cashFlowRows.append(row)
    pendingCashFlowFocusRowID = row.id
    return row.id
  }

  func removeCashFlowRow(rowID: UUID) {
    cashFlowRows.removeAll { $0.id == rowID && $0.source == .manualNew }
  }

  func toggleCashFlowInclude(rowID: UUID) {
    guard let index = cashFlowRows.firstIndex(where: { $0.id == rowID }) else { return }
    cashFlowRows[index].isIncluded.toggle()
    if !cashFlowRows[index].isIncluded {
      cashFlowRows[index].amountText = ""
    }
  }

  // MARK: - Cash Flow CSV Import

  @discardableResult
  func importCashFlowCSV(data: Data) -> CashFlowCSVImportResult {
    let parseResult = CSVParsingService.parseCashFlowCSV(data: data)
    return importCashFlowCSVFromParsedRows(parseResult)
  }

  func loadCashFlowCSVForMapping(data: Data) {
    let headers = CSVParsingService.extractHeaders(from: data)
    guard !headers.isEmpty else {
      _ = importCashFlowCSV(data: data)
      return
    }
    let detectResult = CSVParsingService.autoDetectMapping(headers: headers, schema: .cashFlow)
    switch detectResult {
    case .matched:
      lastCashFlowImportResult = importCashFlowCSV(data: data)

    case .needsUserMapping(let rawHeaders, let partialMap):
      pendingCashFlowCSVData = data
      pendingCashFlowRawHeaders = rawHeaders
      pendingCashFlowSampleRows = CSVParsingService.extractSampleRows(from: data)
      pendingCashFlowPartialMapping = partialMap
      showCashFlowColumnMappingSheet = true
    }
  }

  @discardableResult
  func confirmCashFlowColumnMapping(_ mapping: CSVColumnMapping) -> CashFlowCSVImportResult? {
    showCashFlowColumnMappingSheet = false
    guard let data = pendingCashFlowCSVData else { return nil }
    let parseResult = CSVParsingService.parseCashFlowCSV(data: data, mapping: mapping)
    let result = importCashFlowCSVFromParsedRows(parseResult)
    lastCashFlowImportResult = result
    pendingCashFlowCSVData = nil
    pendingCashFlowRawHeaders = []
    pendingCashFlowSampleRows = []
    pendingCashFlowPartialMapping = [:]
    return result
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

    // Validate asset name uniqueness within each platform before creating anything
    // (avoids expensive normalizedForIdentity on every keystroke during editing)
    for (platform, platformRows) in Dictionary(grouping: includedRows, by: \.platform) {
      var seenNames = [String: String]()
      for row in platformRows {
        let key = row.assetName.normalizedForIdentity
        guard !key.isEmpty else { continue }
        if seenNames[key] != nil {
          throw SnapshotError.duplicateAssetName(row.assetName, platform)
        }
        seenNames[key] = row.assetName
      }
    }

    // Validate cash flow description uniqueness before creating anything
    // (avoids expensive normalizedForIdentity on every keystroke during editing)
    let includedCashFlows = cashFlowRows.filter(\.isIncluded)
    var seenDescriptions = [String: String]()
    for cfRow in includedCashFlows {
      let key = cfRow.cashFlowDescription.normalizedForIdentity
      if let existing = seenDescriptions[key] {
        throw SnapshotError.duplicateCashFlowDescription(existing)
      }
      seenDescriptions[key] = cfRow.cashFlowDescription
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

    for cfRow in includedCashFlows {
      let amount = cfRow.amount ?? Decimal(0)
      let operation = CashFlowOperation(
        cashFlowDescription: cfRow.cashFlowDescription, amount: amount)
      operation.currency = cfRow.currency
      operation.snapshot = snapshot
      modelContext.insert(operation)
    }

    savedSnapshot = snapshot
    return snapshot
  }

  @discardableResult
  func importCSV(data: Data, forPlatform platform: String) -> CSVImportResult {
    let result = CSVParsingService.parseAssetCSV(data: data, importPlatform: nil)
    return importCSVFromParsedRows(result, forPlatform: platform)
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

    let parseResult = CSVParsingService.parseAssetCSV(
      data: data, mapping: mapping, importPlatform: nil)
    let result = importCSVFromParsedRows(parseResult, forPlatform: platform)
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

    // Pre-build lookup: normalizedName → row index for the target platform.
    // Avoids O(m×n) repeated normalization inside the CSV row loop.
    let normalizedPlatform = platform.normalizedForIdentity
    var nameIndex: [String: Int] = [:]
    for (idx, row) in rows.enumerated() where row.platform == platform {
      nameIndex[row.assetName.normalizedForIdentity] = idx
    }

    var matchedCount = 0
    var newCount = 0
    var platformMismatches: [String] = []
    var currencyMismatches: [String] = []

    for csvRow in parseResult.rows {
      if !csvRow.platform.isEmpty,
        csvRow.platform.normalizedForIdentity != normalizedPlatform
      {
        platformMismatches.append(csvRow.assetName)
        continue
      }

      let normalizedCSVName = csvRow.assetName.normalizedForIdentity
      if let index = nameIndex[normalizedCSVName] {
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
        nameIndex[normalizedCSVName] = rows.count
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

  private func importCashFlowCSVFromParsedRows(
    _ parseResult: CSVParseResult<CashFlowCSVRow>
  ) -> CashFlowCSVImportResult {
    // Clear previous CSV cash flow rows: revert CSV-sourced to manual, remove empty ones
    for index in cashFlowRows.indices where cashFlowRows[index].source == .csv {
      cashFlowRows[index].amountText = ""
      cashFlowRows[index].source = .manualNew
    }
    cashFlowRows.removeAll {
      $0.source == .manualNew && $0.cashFlowDescription.trimmingCharacters(in: .whitespaces).isEmpty
        && $0.amountText.isEmpty
    }

    let errors = parseResult.errors.map(\.message)
    let parserWarnings = parseResult.warnings.map(\.message)
    let mainCurrency = SettingsService.shared.mainCurrency

    guard !parseResult.hasErrors else {
      return CashFlowCSVImportResult(
        matchedCount: 0, newCount: 0, errors: errors, parserWarnings: parserWarnings)
    }

    // Pre-build lookup: normalizedDescription → row index.
    // Avoids O(m×c) repeated normalization inside the CSV row loop.
    var descIndex: [String: Int] = [:]
    for (idx, row) in cashFlowRows.enumerated() {
      descIndex[row.cashFlowDescription.normalizedForIdentity] = idx
    }

    var matchedCount = 0
    var newCount = 0

    for csvRow in parseResult.rows {
      let normalizedDesc = csvRow.description.normalizedForIdentity
      if let index = descIndex[normalizedDesc] {
        cashFlowRows[index].amountText = "\(csvRow.amount)"
        cashFlowRows[index].source = .csv
        if !csvRow.currency.isEmpty {
          cashFlowRows[index].currency = csvRow.currency
        }
        matchedCount += 1
      } else {
        let newRow = BulkEntryCashFlowRow(
          id: UUID(), cashFlowDescription: csvRow.description,
          amountText: "\(csvRow.amount)",
          currency: csvRow.currency.isEmpty ? mainCurrency : csvRow.currency,
          isIncluded: true, source: .csv)
        descIndex[normalizedDesc] = cashFlowRows.count
        cashFlowRows.append(newRow)
        newCount += 1
      }
    }

    return CashFlowCSVImportResult(
      matchedCount: matchedCount, newCount: newCount,
      errors: errors, parserWarnings: parserWarnings)
  }

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
