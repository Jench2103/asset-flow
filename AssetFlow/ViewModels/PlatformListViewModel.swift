//
//  PlatformListViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData

/// Data for a single platform row in the list.
struct PlatformRowData: Identifiable {
  /// Platform name serves as the stable identifier (unique, case-insensitive).
  var id: String { name }
  let name: String
  let assetCount: Int
  let totalValue: Decimal
}

/// ViewModel for the Platforms list screen.
///
/// Derives platform data from assets — platforms are not model objects,
/// they are distinct non-empty `Asset.platform` values.
@Observable
@MainActor
final class PlatformListViewModel {
  private let modelContext: ModelContext

  var platformRows: [PlatformRowData] = []

  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  // MARK: - Loading

  /// Fetches all assets, computes platform totals from the latest snapshot,
  /// and builds sorted row data.
  func loadPlatforms() {
    let allAssets = fetchAllAssets()
    let allSnapshots = fetchAllSnapshots()

    // Group assets by non-empty platform
    let assetsByPlatform = Dictionary(
      grouping: allAssets.filter { !$0.platform.isEmpty },
      by: { $0.platform }
    )

    // Build platform → total value lookup from latest snapshot
    let platformValues = buildPlatformValueLookup(allSnapshots: allSnapshots)

    platformRows =
      assetsByPlatform.map { platform, assets in
        PlatformRowData(
          name: platform,
          assetCount: assets.count,
          totalValue: platformValues[platform] ?? 0
        )
      }
      .sorted {
        $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
      }
  }

  // MARK: - Rename

  /// Renames a platform by updating all assets with the old platform name.
  ///
  /// - Parameters:
  ///   - oldName: The current platform name to rename.
  ///   - newName: The desired new platform name.
  /// - Throws: `PlatformError.emptyName` if new name is blank after trimming,
  ///   `PlatformError.duplicateName` if new name conflicts with an existing platform.
  func renamePlatform(from oldName: String, to newName: String) throws {
    let trimmed =
      newName
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

    guard !trimmed.isEmpty else { throw PlatformError.emptyName }

    let allAssets = fetchAllAssets()

    // Check for duplicate (case-insensitive), allowing self-rename with different casing
    let normalizedNew = trimmed.lowercased()
    let normalizedOld = oldName.lowercased()

    if normalizedNew != normalizedOld {
      let existingPlatforms = Set(
        allAssets
          .map { $0.platform.lowercased() }
          .filter { !$0.isEmpty }
      )

      if existingPlatforms.contains(normalizedNew) {
        throw PlatformError.duplicateName(trimmed)
      }
    }

    // Update all assets with the old platform name
    for asset in allAssets where asset.platform == oldName {
      asset.platform = trimmed
    }
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

  /// Builds a lookup of platform name → total market value from the latest snapshot.
  private func buildPlatformValueLookup(
    allSnapshots: [Snapshot]
  ) -> [String: Decimal] {
    guard let latestSnapshot = allSnapshots.last else { return [:] }

    let assetValues = latestSnapshot.assetValues ?? []

    var lookup: [String: Decimal] = [:]
    for sav in assetValues {
      guard let platform = sav.asset?.platform, !platform.isEmpty else { continue }
      lookup[platform, default: 0] += sav.marketValue
    }
    return lookup
  }
}
