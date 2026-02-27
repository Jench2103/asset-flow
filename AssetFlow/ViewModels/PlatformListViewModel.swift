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
  private let settingsService: SettingsService

  var platformRows: [PlatformRowData] = []

  init(modelContext: ModelContext, settingsService: SettingsService? = nil) {
    self.modelContext = modelContext
    self.settingsService = settingsService ?? .shared
  }

  // MARK: - Loading

  /// Fetches all assets, computes platform totals from the latest snapshot,
  /// and builds sorted row data.
  ///
  /// Wraps the load in `withObservationTracking` so that any `@Observable`/`@Model`
  /// property change automatically triggers a reload.
  func loadPlatforms() {
    withObservationTracking {
      performLoadPlatforms()
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        self?.loadPlatforms()
      }
    }
  }

  private func performLoadPlatforms() {
    let allAssets = fetchAllAssets()
    let allSnapshots = fetchAllSnapshots()

    // Group assets by non-empty platform
    let assetsByPlatform = Dictionary(
      grouping: allAssets.filter { !$0.platform.isEmpty },
      by: { $0.platform }
    )

    // Build platform → total value lookup from latest snapshot
    let platformValues = buildPlatformValueLookup(allSnapshots: allSnapshots)

    let rows =
      assetsByPlatform.map { platform, assets in
        PlatformRowData(
          name: platform,
          assetCount: assets.count,
          totalValue: platformValues[platform] ?? 0
        )
      }

    // Sort by stored order; unknown platforms go to the end alphabetically
    let storedOrder = settingsService.platformOrder
    let orderLookup = Dictionary(
      uniqueKeysWithValues: storedOrder.enumerated().map { ($1, $0) }
    )

    platformRows = rows.sorted { lhs, rhs in
      let lhsIndex = orderLookup[lhs.name]
      let rhsIndex = orderLookup[rhs.name]
      switch (lhsIndex, rhsIndex) {
      case (.some(let lhsOrder), .some(let rhsOrder)):
        return lhsOrder < rhsOrder

      case (.some, .none):
        return true

      case (.none, .some):
        return false

      case (.none, .none):
        return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
      }
    }

    // Sync stored order: prune removed platforms, append new ones
    let currentNames = Set(platformRows.map(\.name))
    var updatedOrder = storedOrder.filter { currentNames.contains($0) }
    let knownNames = Set(updatedOrder)
    for row in platformRows where !knownNames.contains(row.name) {
      updatedOrder.append(row.name)
    }
    if updatedOrder != storedOrder {
      settingsService.platformOrder = updatedOrder
    }
  }

  // MARK: - Move

  /// Reorders platforms by moving items at the given offsets to the target position.
  func movePlatforms(from source: IndexSet, to destination: Int) {
    var names = platformRows.map(\.name)
    let adjustedDestination = destination - source.filter { $0 < destination }.count
    let moved = source.sorted().map { names[$0] }
    for index in source.sorted().reversed() {
      names.remove(at: index)
    }
    let insertAt = min(adjustedDestination, names.count)
    names.insert(contentsOf: moved, at: insertAt)
    settingsService.platformOrder = names
    loadPlatforms()
  }

  // MARK: - Rename

  /// Renames a platform by updating all assets with the old platform name.
  ///
  /// - Parameters:
  ///   - oldName: The current platform name to rename.
  ///   - newName: The desired new platform name.
  /// - Returns: The trimmed new platform name.
  /// - Throws: `PlatformError.emptyName` if new name is blank after trimming,
  ///   `PlatformError.duplicateName` if new name conflicts with an existing platform.
  @discardableResult
  func renamePlatform(from oldName: String, to newName: String) throws -> String {
    let trimmed = newName.collapsingWhitespace

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

    return trimmed
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
    let displayCurrency = settingsService.mainCurrency
    let exchangeRate = latestSnapshot.exchangeRate

    var lookup: [String: Decimal] = [:]
    for sav in assetValues {
      guard let asset = sav.asset, !asset.platform.isEmpty else { continue }
      let assetCurrency = asset.currency
      let effectiveCurrency = assetCurrency.isEmpty ? displayCurrency : assetCurrency
      let converted = CurrencyConversionService.convert(
        value: sav.marketValue,
        from: effectiveCurrency,
        to: displayCurrency,
        using: exchangeRate)
      lookup[asset.platform, default: 0] += converted
    }
    return lookup
  }
}
