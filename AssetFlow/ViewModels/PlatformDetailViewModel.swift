//
//  PlatformDetailViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/17.
//

import Foundation
import SwiftData

/// Data for a single asset row within a platform detail view.
struct PlatformAssetRowData: Identifiable {
  var id: UUID { asset.id }
  let asset: Asset
  let latestValue: Decimal?
}

/// Value history entry for a platform's total value at a snapshot date.
struct PlatformValueHistoryEntry: Identifiable {
  var id: String { "\(date.timeIntervalSince1970)-\(totalValue)" }
  let date: Date
  let totalValue: Decimal
}

/// ViewModel for the Platform detail/edit screen.
///
/// Manages renaming a platform (updating all `Asset.platform` values),
/// loading assets on this platform with latest values, and computing
/// value history across snapshots.
///
/// **Note:** Platforms are not model objects — they are derived from distinct
/// non-empty `Asset.platform` string values. Rename mutates all Asset records.
@Observable
@MainActor
final class PlatformDetailViewModel {
  /// The current canonical platform name (updated after successful rename).
  private(set) var platformName: String
  private let modelContext: ModelContext

  /// Text field binding for the platform name.
  var editedName: String

  /// Assets on this platform with their latest composite values.
  var assets: [PlatformAssetRowData] = []

  /// Sum of latest values for all assets on this platform.
  var totalValue: Decimal = 0

  /// Platform total value per snapshot across all snapshots.
  var valueHistory: [PlatformValueHistoryEntry] = []

  init(platformName: String, modelContext: ModelContext) {
    self.platformName = platformName
    self.modelContext = modelContext
    self.editedName = platformName
  }

  // MARK: - Load Data

  /// Fetches all snapshots/asset values, builds composite cache, then loads assets and history.
  func loadData() {
    let allSnapshots = fetchAllSnapshots()
    let allAssetValues = fetchAllAssetValues()

    let compositeCache = buildCompositeCache(
      allSnapshots: allSnapshots, allAssetValues: allAssetValues)

    loadAssets(allSnapshots: allSnapshots, compositeCache: compositeCache)
    loadHistory(allSnapshots: allSnapshots, compositeCache: compositeCache)
  }

  // MARK: - Save (Rename)

  /// Validates the edited name and renames the platform by updating all matching Asset records.
  ///
  /// - Throws: `PlatformError.emptyName` if name is blank after trimming,
  ///   `PlatformError.duplicateName` if name conflicts with another existing platform.
  func save() throws {
    let trimmed =
      editedName
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)

    guard !trimmed.isEmpty else { throw PlatformError.emptyName }

    let allAssets = fetchAllAssets()

    // Check for duplicate (case-insensitive), allowing self-rename with different casing
    let normalizedNew = trimmed.lowercased()
    let normalizedOld = platformName.lowercased()

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
    for asset in allAssets where asset.platform == platformName {
      asset.platform = trimmed
    }

    platformName = trimmed
    editedName = trimmed
  }

  // MARK: - Private Helpers

  private func fetchAllSnapshots() -> [Snapshot] {
    let descriptor = FetchDescriptor<Snapshot>(sortBy: [SortDescriptor(\.date)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  private func fetchAllAssets() -> [Asset] {
    let descriptor = FetchDescriptor<Asset>(sortBy: [SortDescriptor(\.name)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  private func fetchAllAssetValues() -> [SnapshotAssetValue] {
    let descriptor = FetchDescriptor<SnapshotAssetValue>()
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  /// Precomputes composite values for all snapshots to avoid redundant O(N*M) computation.
  private func buildCompositeCache(
    allSnapshots: [Snapshot], allAssetValues: [SnapshotAssetValue]
  ) -> [UUID: [CompositeAssetValue]] {
    var cache: [UUID: [CompositeAssetValue]] = [:]
    for snapshot in allSnapshots {
      cache[snapshot.id] = CarryForwardService.compositeValues(
        for: snapshot, allSnapshots: allSnapshots, allAssetValues: allAssetValues)
    }
    return cache
  }

  /// Loads assets on this platform with their latest composite values.
  private func loadAssets(
    allSnapshots: [Snapshot], compositeCache: [UUID: [CompositeAssetValue]]
  ) {
    // Build latest value lookup from most recent composite snapshot
    var latestValueLookup: [UUID: Decimal] = [:]
    if let latestSnapshot = allSnapshots.last,
      let compositeValues = compositeCache[latestSnapshot.id]
    {
      for cv in compositeValues where cv.asset.platform == platformName {
        latestValueLookup[cv.asset.id] = cv.marketValue
      }
    }

    // Collect all assets that belong to this platform
    let platformAssets = fetchAllAssets().filter { $0.platform == platformName }

    assets =
      platformAssets.map { asset in
        PlatformAssetRowData(
          asset: asset,
          latestValue: latestValueLookup[asset.id]
        )
      }
      .sorted {
        $0.asset.name.localizedCaseInsensitiveCompare($1.asset.name) == .orderedAscending
      }

    totalValue = assets.reduce(Decimal(0)) { $0 + ($1.latestValue ?? 0) }
  }

  /// Computes value history across all snapshots for this platform.
  private func loadHistory(
    allSnapshots: [Snapshot], compositeCache: [UUID: [CompositeAssetValue]]
  ) {
    var entries: [PlatformValueHistoryEntry] = []

    for snapshot in allSnapshots {
      let compositeValues = compositeCache[snapshot.id] ?? []

      let platformValue =
        compositeValues
        .filter { $0.asset.platform == platformName }
        .reduce(Decimal(0)) { $0 + $1.marketValue }

      entries.append(
        PlatformValueHistoryEntry(date: snapshot.date, totalValue: platformValue))
    }

    valueHistory = entries
  }
}
