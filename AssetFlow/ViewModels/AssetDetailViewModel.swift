//
//  AssetDetailViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData

/// Value history entry for an asset's recorded market value at a snapshot date.
struct AssetValueHistoryEntry: Identifiable {
  var id: String { "\(date.timeIntervalSince1970)-\(marketValue)" }
  let date: Date
  let marketValue: Decimal
}

/// ViewModel for the Asset detail/edit screen.
///
/// Manages editing asset properties (name, platform, category),
/// loading value history from snapshots, and deletion with validation.
@Observable
@MainActor
final class AssetDetailViewModel {
  let asset: Asset
  private let modelContext: ModelContext

  var editedName: String
  var editedPlatform: String
  var editedCategory: Category?
  var valueHistory: [AssetValueHistoryEntry] = []

  init(asset: Asset, modelContext: ModelContext) {
    self.asset = asset
    self.modelContext = modelContext
    self.editedName = asset.name
    self.editedPlatform = asset.platform
    self.editedCategory = asset.category
  }

  // MARK: - Computed Properties

  /// Whether the asset can be deleted (has no snapshot values).
  var canDelete: Bool {
    (asset.snapshotAssetValues?.count ?? 0) == 0
  }

  /// Explanatory text for why the asset cannot be deleted, or nil if deletion is allowed.
  var deleteExplanation: String? {
    guard !canDelete else { return nil }
    return AssetError.cannotDelete(snapshotCount: snapshotCount).errorDescription
  }

  /// Number of distinct snapshots this asset appears in.
  var snapshotCount: Int {
    let savs = asset.snapshotAssetValues ?? []
    let snapshotIDs = Set(savs.compactMap { $0.snapshot?.id })
    return snapshotIDs.count
  }

  // MARK: - Value History

  /// Loads the value history from directly recorded snapshot asset values (no carry-forward).
  func loadValueHistory() {
    let savs = asset.snapshotAssetValues ?? []

    valueHistory = savs.compactMap { sav in
      guard let snapshotDate = sav.snapshot?.date else { return nil }
      return AssetValueHistoryEntry(
        date: snapshotDate,
        marketValue: sav.marketValue
      )
    }
    .sorted { $0.date < $1.date }
  }

  // MARK: - Queries

  /// Returns all distinct, non-empty platforms from existing assets.
  func existingPlatforms() -> [String] {
    let descriptor = FetchDescriptor<Asset>()
    let allAssets = (try? modelContext.fetch(descriptor)) ?? []
    let platforms = Set(allAssets.map(\.platform).filter { !$0.isEmpty })
    return platforms.sorted()
  }

  /// Returns all existing categories sorted by name.
  func existingCategories() -> [Category] {
    let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  /// Resolves a category by name, reusing existing (case-insensitive) or creating new.
  func resolveCategory(name: String) -> Category? {
    modelContext.resolveCategory(name: name)
  }

  // MARK: - Save

  /// Validates and saves edited properties to the asset model.
  ///
  /// - Throws: `AssetError.duplicateIdentity` if the new (name, platform) conflicts
  ///   with another existing asset.
  func save() throws {
    let newNormalizedName = editedName.normalizedForIdentity
    let newNormalizedPlatform = editedPlatform.normalizedForIdentity

    // Check for conflicts with other assets (exclude self)
    let descriptor = FetchDescriptor<Asset>()
    let allAssets = (try? modelContext.fetch(descriptor)) ?? []

    let hasConflict = allAssets.contains { other in
      other.id != asset.id
        && other.normalizedName == newNormalizedName
        && other.normalizedPlatform == newNormalizedPlatform
    }

    if hasConflict {
      throw AssetError.duplicateIdentity(name: editedName, platform: editedPlatform)
    }

    // Apply changes to the asset model (retroactive update)
    asset.name = editedName
    asset.platform = editedPlatform
    asset.category = editedCategory
  }

  // MARK: - Delete

  /// Deletes the asset from the model context.
  /// Only call when `canDelete` is true.
  func deleteAsset() {
    modelContext.delete(asset)
  }
}
