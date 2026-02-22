//
//  CategoryDetailViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData

/// Value history entry for a category's total value at a snapshot date.
struct CategoryValueHistoryEntry: Identifiable {
  var id: String { "\(date.timeIntervalSince1970)-\(totalValue)" }
  let date: Date
  let totalValue: Decimal
}

/// Allocation history entry for a category's allocation percentage at a snapshot date.
struct CategoryAllocationHistoryEntry: Identifiable {
  var id: String { "\(date.timeIntervalSince1970)-\(allocationPercentage)" }
  let date: Date
  let allocationPercentage: Decimal
}

/// Data for a single asset row within a category detail view.
struct CategoryAssetRowData: Identifiable {
  var id: UUID { asset.id }
  let asset: Asset
  let latestValue: Decimal?
}

/// ViewModel for the Category detail/edit screen.
///
/// Manages editing category properties (name, target allocation),
/// loading assets in the category with latest values,
/// computing value and allocation history across snapshots,
/// and deletion with validation.
@Observable
@MainActor
final class CategoryDetailViewModel {
  let category: Category
  private let modelContext: ModelContext
  private let settingsService: SettingsService

  var editedName: String
  var editedTargetAllocation: Decimal?

  /// Text binding for the target allocation text field.
  /// Parses the text into `editedTargetAllocation` on change.
  var targetAllocationText: String {
    didSet {
      guard targetAllocationText != oldValue else { return }
      let trimmed = targetAllocationText.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty {
        editedTargetAllocation = nil
      } else if let value = Decimal(string: trimmed) {
        editedTargetAllocation = value
      }
    }
  }

  var assets: [CategoryAssetRowData] = []
  var valueHistory: [CategoryValueHistoryEntry] = []
  var allocationHistory: [CategoryAllocationHistoryEntry] = []

  init(category: Category, modelContext: ModelContext, settingsService: SettingsService = .shared) {
    self.category = category
    self.modelContext = modelContext
    self.settingsService = settingsService
    self.editedName = category.name
    self.editedTargetAllocation = category.targetAllocationPercentage
    if let target = category.targetAllocationPercentage {
      self.targetAllocationText = NSDecimalNumber(decimal: target).stringValue
    } else {
      self.targetAllocationText = ""
    }
  }

  // MARK: - Computed Properties

  /// Whether the category can be deleted (has no assigned assets).
  var canDelete: Bool {
    (category.assets ?? []).isEmpty
  }

  /// Explanatory text for why the category cannot be deleted, or nil if deletion is allowed.
  var deleteExplanation: String? {
    guard !canDelete else { return nil }
    let assetCount = (category.assets ?? []).count
    return CategoryError.cannotDelete(assetCount: assetCount).errorDescription
  }

  // MARK: - Load Data

  /// Loads assets, value history, and allocation history for this category.
  func loadData() {
    let allSnapshots = fetchAllSnapshots()

    loadAssets(allSnapshots: allSnapshots)
    loadHistory(allSnapshots: allSnapshots)
  }

  // MARK: - Save

  /// Validates and saves edited properties to the category model.
  ///
  /// - Throws: `CategoryError.emptyName` if name is blank,
  ///   `CategoryError.invalidTargetAllocation` if target is outside 0-100,
  ///   `CategoryError.duplicateName` if name conflicts with another category.
  func save() throws {
    let trimmed = editedName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { throw CategoryError.emptyName }

    if let target = editedTargetAllocation {
      guard target >= 0 && target <= 100 else { throw CategoryError.invalidTargetAllocation }
    }

    // Check for conflicts with other categories (exclude self)
    let descriptor = FetchDescriptor<Category>()
    let allCategories = (try? modelContext.fetch(descriptor)) ?? []

    let hasConflict = allCategories.contains { other in
      other.id != category.id
        && other.name.lowercased() == trimmed.lowercased()
    }

    if hasConflict {
      throw CategoryError.duplicateName(trimmed)
    }

    category.name = trimmed
    category.targetAllocationPercentage = editedTargetAllocation
  }

  // MARK: - Delete

  /// Deletes the category from the model context.
  /// Only call when `canDelete` is true.
  func deleteCategory() {
    modelContext.delete(category)
  }

  // MARK: - Private Helpers

  private func fetchAllSnapshots() -> [Snapshot] {
    let descriptor = FetchDescriptor<Snapshot>(sortBy: [SortDescriptor(\.date)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  /// Loads assets in this category with their latest values.
  private func loadAssets(allSnapshots: [Snapshot]) {
    let categoryAssets = category.assets ?? []

    // Build latest value lookup from most recent snapshot
    var latestValueLookup: [UUID: Decimal] = [:]
    if let latestSnapshot = allSnapshots.last {
      for sav in latestSnapshot.assetValues ?? [] {
        guard let asset = sav.asset else { continue }
        latestValueLookup[asset.id] = sav.marketValue
      }
    }

    assets =
      categoryAssets.map { asset in
        CategoryAssetRowData(
          asset: asset,
          latestValue: latestValueLookup[asset.id]
        )
      }
      .sorted {
        $0.asset.name.localizedCaseInsensitiveCompare($1.asset.name) == .orderedAscending
      }
  }

  /// Computes value and allocation history across all snapshots.
  ///
  /// **Note:** Values reflect **current** category membership applied retroactively.
  /// The data model does not track historical category assignments, so an asset
  /// moved between categories will appear in its current category for all past snapshots.
  private func loadHistory(allSnapshots: [Snapshot]) {
    let categoryAssetIDs = Set((category.assets ?? []).map(\.id))

    var valueEntries: [CategoryValueHistoryEntry] = []
    var allocationEntries: [CategoryAllocationHistoryEntry] = []

    let displayCurrency = settingsService.mainCurrency

    for snapshot in allSnapshots {
      let assetValues = snapshot.assetValues ?? []
      let exchangeRate = snapshot.exchangeRate

      let totalValue = CurrencyConversionService.totalValue(
        for: snapshot, displayCurrency: displayCurrency,
        exchangeRate: exchangeRate)

      let categoryValue =
        assetValues
        .filter { sav in
          guard let assetID = sav.asset?.id else { return false }
          return categoryAssetIDs.contains(assetID)
        }
        .reduce(Decimal(0)) { sum, sav in
          let assetCurrency = sav.asset?.currency ?? ""
          let effectiveCurrency = assetCurrency.isEmpty ? displayCurrency : assetCurrency
          return sum
            + CurrencyConversionService.convert(
              value: sav.marketValue,
              from: effectiveCurrency,
              to: displayCurrency,
              using: exchangeRate)
        }

      valueEntries.append(
        CategoryValueHistoryEntry(date: snapshot.date, totalValue: categoryValue))

      let allocation = CalculationService.categoryAllocation(
        categoryValue: categoryValue, totalValue: totalValue)
      allocationEntries.append(
        CategoryAllocationHistoryEntry(date: snapshot.date, allocationPercentage: allocation))
    }

    valueHistory = valueEntries
    allocationHistory = allocationEntries
  }
}
