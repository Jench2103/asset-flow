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
  var canSave: Bool { includedCount > 0 }

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

  func saveSnapshot() throws -> Snapshot {
    let includedRows = rows.filter(\.isIncluded)
    guard !includedRows.isEmpty else {
      throw SnapshotError.noAssetsIncluded
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
        if let categoryName = row.csvCategory?.trimmingCharacters(in: .whitespaces),
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
  func importCSV(data: Data, forPlatform platform: String) -> [String] {
    let result = CSVParsingService.parseAssetCSV(data: data, importPlatform: platform)

    // Clear previous CSV values for this platform
    for index in rows.indices where rows[index].platform == platform && rows[index].source == .csv {
      if rows[index].asset != nil {
        rows[index].newValueText = ""
        rows[index].source = .manual
      }
    }
    rows.removeAll { $0.platform == platform && $0.source == .csv && $0.asset == nil }

    var errors: [String] = []
    errors.append(contentsOf: result.errors.map(\.message))

    let mainCurrency = SettingsService.shared.mainCurrency

    for csvRow in result.rows {
      let normalizedCSVName = csvRow.assetName.normalizedForIdentity
      if let index = rows.firstIndex(where: {
        $0.platform == platform && $0.assetName.normalizedForIdentity == normalizedCSVName
      }) {
        rows[index].newValueText = "\(csvRow.marketValue)"
        rows[index].source = .csv
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
          csvCategory: nil
        )
        rows.append(newRow)
      }
    }

    return errors
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
          csvCategory: nil
        )
      }.sorted { ($0.platform, $0.assetName) < ($1.platform, $1.assetName) }
  }
}
