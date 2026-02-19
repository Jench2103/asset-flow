//
//  SnapshotDetailViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData

/// Data for category allocation display.
struct CategoryAllocationData: Sendable {
  let categoryName: String
  let value: Decimal
  let percentage: Decimal
}

/// ViewModel for the Snapshot detail screen.
///
/// Manages asset add/edit/remove, cash flow add/edit/remove,
/// and category allocation summary.
@Observable
@MainActor
class SnapshotDetailViewModel {
  let snapshot: Snapshot
  private let modelContext: ModelContext

  /// Direct asset values in this snapshot.
  var assetValues: [SnapshotAssetValue] = []

  init(snapshot: Snapshot, modelContext: ModelContext) {
    self.snapshot = snapshot
    self.modelContext = modelContext
  }

  // MARK: - Computed Properties

  /// Total portfolio value for this snapshot.
  var totalValue: Decimal {
    assetValues.reduce(Decimal(0)) { $0 + $1.marketValue }
  }

  /// Net cash flow for this snapshot (sum of all CashFlowOperation amounts).
  var netCashFlow: Decimal {
    let operations = snapshot.cashFlowOperations ?? []
    return operations.reduce(Decimal(0)) { $0 + $1.amount }
  }

  /// Asset values sorted by platform (alphabetical), then asset name (alphabetical).
  var sortedAssetValues: [SnapshotAssetValue] {
    assetValues
      .filter { $0.asset != nil }
      .sorted { lhs, rhs in
        let lhsAsset = lhs.asset!
        let rhsAsset = rhs.asset!
        if lhsAsset.platform != rhsAsset.platform {
          return lhsAsset.platform.localizedCaseInsensitiveCompare(rhsAsset.platform)
            == .orderedAscending
        }
        return lhsAsset.name.localizedCaseInsensitiveCompare(rhsAsset.name) == .orderedAscending
      }
  }

  /// Cash flow operations sorted by description for stable display order.
  var sortedCashFlowOperations: [CashFlowOperation] {
    (snapshot.cashFlowOperations ?? []).sorted { $0.cashFlowDescription < $1.cashFlowDescription }
  }

  /// Category allocation summary for this snapshot.
  var categoryAllocations: [CategoryAllocationData] {
    let total = totalValue
    guard total > 0 else { return [] }

    var categoryValues: [String: Decimal] = [:]

    for sav in assetValues {
      guard let asset = sav.asset else { continue }
      let categoryName = asset.category?.name ?? "Uncategorized"
      categoryValues[categoryName, default: 0] += sav.marketValue
    }

    return categoryValues.map { name, value in
      CategoryAllocationData(
        categoryName: name,
        value: value,
        percentage: CalculationService.categoryAllocation(
          categoryValue: value, totalValue: total)
      )
    }.sorted { $0.value > $1.value }
  }

  // MARK: - Load Data

  /// Loads (or reloads) asset values for the snapshot.
  func loadAssetValues() {
    assetValues = snapshot.assetValues ?? []
  }

  // MARK: - Add Asset: Existing

  /// Adds an existing asset to this snapshot with the given market value.
  ///
  /// - Throws: `SnapshotError.assetAlreadyInSnapshot` if the asset is already in this snapshot.
  func addExistingAsset(_ asset: Asset, marketValue: Decimal) throws {
    // Check if asset already exists in this snapshot
    let existingValues = snapshot.assetValues ?? []
    if existingValues.contains(where: { $0.asset?.id == asset.id }) {
      throw SnapshotError.assetAlreadyInSnapshot(asset.name)
    }

    let sav = SnapshotAssetValue(marketValue: marketValue)
    sav.snapshot = snapshot
    sav.asset = asset
    modelContext.insert(sav)
  }

  // MARK: - Add Asset: New

  /// Creates a new asset (or reuses an existing one) and adds it to this snapshot.
  ///
  /// - Throws: `SnapshotError.assetAlreadyInSnapshot` if the (name, platform) already exists
  ///   in this snapshot.
  func addNewAsset(
    name: String,
    platform: String,
    category: Category?,
    marketValue: Decimal
  ) throws {
    // Normalize for matching
    let normalizedName = name.normalizedForIdentity
    let normalizedPlatform = platform.normalizedForIdentity

    // Check if this asset identity already exists in the snapshot
    let existingValues = snapshot.assetValues ?? []
    if existingValues.contains(where: { sav in
      guard let asset = sav.asset else { return false }
      return asset.normalizedName == normalizedName
        && asset.normalizedPlatform == normalizedPlatform
    }) {
      throw SnapshotError.assetAlreadyInSnapshot(name)
    }

    // Find or create the asset record
    let asset = modelContext.findOrCreateAsset(name: name, platform: platform)

    // Assign category if provided
    if let category = category {
      asset.category = category
    }

    // Create the SnapshotAssetValue
    let sav = SnapshotAssetValue(marketValue: marketValue)
    sav.snapshot = snapshot
    sav.asset = asset
    modelContext.insert(sav)
  }

  // MARK: - Edit Asset Value

  /// Updates the market value of a direct SnapshotAssetValue.
  func editAssetValue(_ sav: SnapshotAssetValue, newValue: Decimal) throws {
    sav.marketValue = newValue
  }

  // MARK: - Remove Asset

  /// Removes a SnapshotAssetValue from the snapshot. The Asset record is preserved.
  func removeAsset(_ sav: SnapshotAssetValue) {
    modelContext.delete(sav)
  }

  // MARK: - Cash Flow Operations

  /// Adds a new cash flow operation to this snapshot.
  ///
  /// - Throws: `SnapshotError.duplicateCashFlowDescription` if the description already exists.
  func addCashFlow(description: String, amount: Decimal) throws {
    let operations = snapshot.cashFlowOperations ?? []
    let normalizedDesc = description.trimmingCharacters(in: .whitespaces).lowercased()

    if operations.contains(where: {
      $0.cashFlowDescription.trimmingCharacters(in: .whitespaces).lowercased()
        == normalizedDesc
    }) {
      throw SnapshotError.duplicateCashFlowDescription(description)
    }

    let operation = CashFlowOperation(cashFlowDescription: description, amount: amount)
    operation.snapshot = snapshot
    modelContext.insert(operation)
  }

  /// Edits an existing cash flow operation.
  ///
  /// - Throws: `SnapshotError.duplicateCashFlowDescription` if the new description conflicts
  ///   with another operation in this snapshot.
  func editCashFlow(
    _ operation: CashFlowOperation,
    newDescription: String,
    newAmount: Decimal
  ) throws {
    let operations = snapshot.cashFlowOperations ?? []
    let normalizedNew = newDescription.trimmingCharacters(in: .whitespaces).lowercased()
    let normalizedOld =
      operation.cashFlowDescription.trimmingCharacters(in: .whitespaces).lowercased()

    // Only check for duplicates if the description actually changed
    if normalizedNew != normalizedOld {
      if operations.contains(where: {
        $0.id != operation.id
          && $0.cashFlowDescription.trimmingCharacters(in: .whitespaces).lowercased()
            == normalizedNew
      }) {
        throw SnapshotError.duplicateCashFlowDescription(newDescription)
      }
    }

    operation.cashFlowDescription = newDescription
    operation.amount = newAmount
  }

  /// Removes a cash flow operation from the snapshot.
  func removeCashFlow(_ operation: CashFlowOperation) {
    modelContext.delete(operation)
  }

  // MARK: - Delete Snapshot

  /// Deletes this snapshot from the model context.
  func deleteSnapshot() {
    modelContext.delete(snapshot)
  }

  /// Returns data for the delete confirmation dialog.
  func deleteConfirmationData() -> SnapshotConfirmationData {
    SnapshotConfirmationData(
      date: snapshot.date,
      assetCount: snapshot.assetValues?.count ?? 0,
      cashFlowCount: snapshot.cashFlowOperations?.count ?? 0
    )
  }

  // MARK: - Category Resolution

  /// Resolves a category by name, reusing an existing one (case-insensitive) or creating a new one.
  func resolveCategory(name: String) -> Category? {
    modelContext.resolveCategory(name: name)
  }

}
