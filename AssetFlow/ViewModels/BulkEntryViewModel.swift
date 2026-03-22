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
