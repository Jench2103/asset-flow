//
//  CategoryListViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData

/// Data for a single category row in the list.
struct CategoryRowData: Identifiable {
  var id: UUID { category.id }
  let category: Category
  let targetAllocation: Decimal?
  let currentAllocation: Decimal?
  let currentValue: Decimal
  let assetCount: Int
}

/// ViewModel for the Categories list screen.
///
/// Manages category listing with allocation computation,
/// and category creation, editing, and deletion with validation.
@Observable
@MainActor
final class CategoryListViewModel {
  private let modelContext: ModelContext

  var categoryRows: [CategoryRowData] = []
  var targetAllocationSumWarning: String?

  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  // MARK: - Loading

  /// Fetches all categories, computes current values and allocations from the
  /// most recent snapshot, and builds sorted row data.
  func loadCategories() {
    let allCategories = fetchAllCategories()
    let allSnapshots = fetchAllSnapshots()

    // Build latest value lookup grouped by category
    let categoryValues = buildCategoryValueLookup(
      categories: allCategories, allSnapshots: allSnapshots)

    let totalValue = categoryValues.values.reduce(Decimal(0), +)
    let hasSnapshots = !allSnapshots.isEmpty

    normalizeDisplayOrderIfNeeded(allCategories)

    categoryRows =
      allCategories.map { category in
        let value = categoryValues[category.id] ?? 0
        let allocation: Decimal? =
          hasSnapshots
          ? CalculationService.categoryAllocation(
            categoryValue: value, totalValue: totalValue)
          : nil
        return CategoryRowData(
          category: category,
          targetAllocation: category.targetAllocationPercentage,
          currentAllocation: allocation,
          currentValue: value,
          assetCount: (category.assets ?? []).count
        )
      }
      .sorted {
        if $0.category.displayOrder != $1.category.displayOrder {
          return $0.category.displayOrder < $1.category.displayOrder
        }
        return $0.category.name.localizedCaseInsensitiveCompare($1.category.name)
          == .orderedAscending
      }

    targetAllocationSumWarning = computeTargetAllocationWarning(categories: allCategories)
  }

  // MARK: - Create

  /// Creates a new category with the given name and optional target allocation.
  ///
  /// - Throws: `CategoryError.emptyName` if name is blank,
  ///   `CategoryError.invalidTargetAllocation` if target is outside 0-100,
  ///   `CategoryError.duplicateName` if name conflicts with existing category.
  @discardableResult
  func createCategory(name: String, targetAllocation: Decimal?) throws -> Category {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { throw CategoryError.emptyName }

    if let target = targetAllocation {
      guard target >= 0 && target <= 100 else { throw CategoryError.invalidTargetAllocation }
    }

    guard !isDuplicateName(trimmed, excludingID: nil) else {
      throw CategoryError.duplicateName(trimmed)
    }

    let category = Category(name: trimmed, targetAllocationPercentage: targetAllocation)
    category.displayOrder = nextDisplayOrder()
    modelContext.insert(category)
    return category
  }

  // MARK: - Edit

  /// Updates category name and target allocation with validation.
  ///
  /// - Throws: `CategoryError.emptyName` if name is blank,
  ///   `CategoryError.invalidTargetAllocation` if target is outside 0-100,
  ///   `CategoryError.duplicateName` if name conflicts with another category.
  func editCategory(
    _ category: Category, newName: String, newTargetAllocation: Decimal?
  ) throws {
    let trimmed = newName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { throw CategoryError.emptyName }

    if let target = newTargetAllocation {
      guard target >= 0 && target <= 100 else { throw CategoryError.invalidTargetAllocation }
    }

    guard !isDuplicateName(trimmed, excludingID: category.id) else {
      throw CategoryError.duplicateName(trimmed)
    }

    category.name = trimmed
    category.targetAllocationPercentage = newTargetAllocation
  }

  // MARK: - Delete

  /// Deletes a category if it has no assigned assets.
  ///
  /// - Throws: `CategoryError.cannotDelete` if assets are assigned.
  func deleteCategory(_ category: Category) throws {
    let assets = category.assets ?? []
    guard assets.isEmpty else {
      throw CategoryError.cannotDelete(assetCount: assets.count)
    }
    modelContext.delete(category)
    compactDisplayOrder()
  }

  // MARK: - Move

  /// Reorders categories by moving items at the given offsets to the target position.
  ///
  /// Implements the same semantics as `Array.move(fromOffsets:toOffset:)` from SwiftUI
  /// without requiring a SwiftUI import in the ViewModel layer.
  func moveCategories(from source: IndexSet, to destination: Int) {
    var categories = categoryRows.map(\.category)
    // Adjust destination for removals before the insertion point
    let adjustedDestination = destination - source.filter { $0 < destination }.count
    let moved = source.sorted().map { categories[$0] }
    // Remove from highest index first to preserve indices
    for index in source.sorted().reversed() {
      categories.remove(at: index)
    }
    let insertAt = min(adjustedDestination, categories.count)
    categories.insert(contentsOf: moved, at: insertAt)
    for (index, category) in categories.enumerated() {
      category.displayOrder = index
    }
    loadCategories()
  }

  // MARK: - Private Helpers

  private func fetchAllCategories() -> [Category] {
    let descriptor = FetchDescriptor<Category>(
      sortBy: [SortDescriptor(\.displayOrder), SortDescriptor(\.name)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  /// Returns the next available displayOrder value.
  private func nextDisplayOrder() -> Int {
    let allCategories = fetchAllCategories()
    return (allCategories.map(\.displayOrder).max() ?? -1) + 1
  }

  /// Compacts displayOrder values after a deletion to remove gaps.
  private func compactDisplayOrder() {
    let allCategories = fetchAllCategories()
    for (index, category) in allCategories.enumerated() {
      category.displayOrder = index
    }
  }

  /// Normalizes displayOrder when all categories have the same value (migration scenario).
  private func normalizeDisplayOrderIfNeeded(_ categories: [Category]) {
    guard categories.count > 1 else { return }
    let allSame = categories.allSatisfy { $0.displayOrder == categories[0].displayOrder }
    guard allSame else { return }
    let sorted = categories.sorted {
      $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
    }
    for (index, category) in sorted.enumerated() {
      category.displayOrder = index
    }
  }

  private func fetchAllSnapshots() -> [Snapshot] {
    let descriptor = FetchDescriptor<Snapshot>(sortBy: [SortDescriptor(\.date)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  /// Builds a lookup of category ID → total market value from the latest snapshot.
  private func buildCategoryValueLookup(
    categories: [Category],
    allSnapshots: [Snapshot]
  ) -> [UUID: Decimal] {
    guard let latestSnapshot = allSnapshots.last else { return [:] }

    let assetValues = latestSnapshot.assetValues ?? []

    var lookup: [UUID: Decimal] = [:]
    for sav in assetValues {
      guard let categoryID = sav.asset?.category?.id else { continue }
      lookup[categoryID, default: 0] += sav.marketValue
    }
    return lookup
  }

  /// Checks if a category name already exists (case-insensitive), optionally excluding one ID.
  private func isDuplicateName(_ name: String, excludingID: UUID?) -> Bool {
    let normalized = name.lowercased()
    let descriptor = FetchDescriptor<Category>()
    let allCategories = (try? modelContext.fetch(descriptor)) ?? []

    return allCategories.contains { category in
      category.name.lowercased() == normalized
        && category.id != excludingID
    }
  }

  /// Computes the target allocation sum warning message, or nil if sum is 100%.
  private func computeTargetAllocationWarning(categories: [Category]) -> String? {
    let categoriesWithTargets = categories.filter {
      $0.targetAllocationPercentage != nil
    }

    guard !categoriesWithTargets.isEmpty else { return nil }

    let sum = categoriesWithTargets.reduce(Decimal(0)) {
      $0 + ($1.targetAllocationPercentage ?? 0)
    }

    guard sum != 100 else { return nil }

    return String(
      localized:
        "Target allocations sum to \(sum.formattedPercentage()) instead of 100%.",
      table: "Category")
  }
}
