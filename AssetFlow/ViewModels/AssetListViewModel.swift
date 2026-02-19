//
//  AssetListViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData

/// Grouping mode for the asset list.
enum AssetGroupingMode: CaseIterable {
  case byPlatform
  case byCategory
}

/// Data for a single asset row in the list.
struct AssetRowData {
  let asset: Asset
  let latestValue: Decimal?
}

/// A group of assets with a header name.
struct AssetGroup {
  let name: String
  let assets: [AssetRowData]
}

/// ViewModel for the Assets list screen.
///
/// Manages asset listing with grouping (by platform or category),
/// latest value computation from the most recent composite snapshot,
/// and asset deletion with validation.
@Observable
@MainActor
final class AssetListViewModel {
  private let modelContext: ModelContext

  var groupingMode: AssetGroupingMode = .byPlatform
  var groups: [AssetGroup] = []

  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  // MARK: - Loading

  /// Fetches all assets, computes latest values from the most recent snapshot,
  /// and groups them by the current grouping mode.
  func loadAssets() {
    let allAssets = fetchAllAssets()
    let allSnapshots = fetchAllSnapshots()

    // Build latest value lookup from most recent snapshot
    let latestValueLookup = buildLatestValueLookup(allSnapshots: allSnapshots)

    // Build row data for each asset
    let rowDataList = allAssets.map { asset in
      AssetRowData(
        asset: asset,
        latestValue: latestValueLookup[asset.id]
      )
    }

    // Group and sort
    groups = buildGroups(from: rowDataList)
  }

  // MARK: - Deletion

  /// Deletes an asset if it has no snapshot values.
  ///
  /// - Throws: `AssetError.cannotDelete` if the asset has snapshot values.
  func deleteAsset(_ asset: Asset) throws {
    let savs = asset.snapshotAssetValues ?? []
    guard savs.isEmpty else {
      let snapshotCount = Set(savs.compactMap { $0.snapshot?.id }).count
      throw AssetError.cannotDelete(snapshotCount: snapshotCount)
    }
    modelContext.delete(asset)
  }

  // MARK: - Private Helpers

  private func fetchAllAssets() -> [Asset] {
    let descriptor = FetchDescriptor<Asset>(sortBy: [SortDescriptor(\.name)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  private func fetchAllSnapshots() -> [Snapshot] {
    let descriptor = FetchDescriptor<Snapshot>(sortBy: [SortDescriptor(\.date)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  /// Builds a lookup of asset ID → latest market value from the most recent snapshot.
  private func buildLatestValueLookup(
    allSnapshots: [Snapshot]
  ) -> [UUID: Decimal] {
    guard let latestSnapshot = allSnapshots.last else { return [:] }

    let assetValues = latestSnapshot.assetValues ?? []

    var lookup: [UUID: Decimal] = [:]
    for sav in assetValues {
      guard let asset = sav.asset else { continue }
      lookup[asset.id] = sav.marketValue
    }
    return lookup
  }

  /// Groups row data by the current grouping mode, sorts groups alphabetically
  /// with the "missing" group last, and sorts assets within each group alphabetically.
  private func buildGroups(from rowDataList: [AssetRowData]) -> [AssetGroup] {
    let noPlatformName = String(localized: "(No Platform)", table: "Asset")
    let uncategorizedName = String(localized: "(Uncategorized)", table: "Asset")

    let grouped: [String: [AssetRowData]]
    let missingGroupName: String

    switch groupingMode {
    case .byPlatform:
      missingGroupName = noPlatformName
      grouped = Dictionary(grouping: rowDataList) { row in
        row.asset.platform.isEmpty ? noPlatformName : row.asset.platform
      }

    case .byCategory:
      missingGroupName = uncategorizedName
      grouped = Dictionary(grouping: rowDataList) { row in
        row.asset.category?.name ?? uncategorizedName
      }
    }

    return
      grouped
      .map { key, rows in
        AssetGroup(
          name: key,
          assets: rows.sorted {
            $0.asset.name.localizedCaseInsensitiveCompare($1.asset.name) == .orderedAscending
          }
        )
      }
      .sorted { lhs, rhs in
        // Missing group always last
        if lhs.name == missingGroupName { return false }
        if rhs.name == missingGroupName { return true }
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
  }
}
