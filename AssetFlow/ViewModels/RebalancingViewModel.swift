//
//  RebalancingViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData

/// Data for a rebalancing suggestion row (categories with target allocations).
struct RebalancingRowData: Identifiable {
  var id: String { categoryName }
  let categoryName: String
  let currentValue: Decimal
  let currentPercentage: Decimal
  let targetPercentage: Decimal
  let difference: Decimal
  let actionText: String
  let actionType: RebalancingActionType
}

/// Data for a category row without a target allocation.
struct NoTargetRowData: Identifiable {
  var id: String { categoryName }
  let categoryName: String
  let currentValue: Decimal
  let currentPercentage: Decimal
}

/// Data for the uncategorized assets row.
struct UncategorizedRowData {
  let currentValue: Decimal
  let currentPercentage: Decimal
}

/// ViewModel for the Rebalancing screen.
///
/// Loads current and target allocations, computes rebalancing suggestions
/// using `RebalancingCalculator`, and presents results for display.
/// This is a read-only view — no data modification.
@Observable
@MainActor
final class RebalancingViewModel {
  private let modelContext: ModelContext

  var suggestions: [RebalancingRowData] = []
  var noTargetRows: [NoTargetRowData] = []
  var uncategorizedRow: UncategorizedRowData?
  var summaryTexts: [String] = []
  var totalPortfolioValue: Decimal = 0

  var isEmpty: Bool {
    suggestions.isEmpty && noTargetRows.isEmpty && uncategorizedRow == nil
  }

  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  // MARK: - Loading

  /// Loads all rebalancing data from the latest snapshot.
  ///
  /// Wraps the load in `withObservationTracking` so that any `@Observable`/`@Model`
  /// property change automatically triggers a reload.
  func loadRebalancing() {
    withObservationTracking {
      performLoadRebalancing()
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        self?.loadRebalancing()
      }
    }
  }

  private func performLoadRebalancing() {
    let allSnapshots = fetchAllSnapshots()
    let allCategories = fetchAllCategories()

    // Clear state
    suggestions = []
    noTargetRows = []
    uncategorizedRow = nil
    summaryTexts = []
    totalPortfolioValue = 0

    guard let latestSnapshot = allSnapshots.last else { return }

    let displayCurrency = SettingsService.shared.mainCurrency
    totalPortfolioValue = CurrencyConversionService.totalValue(
      for: latestSnapshot, displayCurrency: displayCurrency,
      exchangeRate: latestSnapshot.exchangeRate)

    guard totalPortfolioValue > 0 else { return }

    // Group values by category with currency conversion
    let catValues = CurrencyConversionService.categoryValues(
      for: latestSnapshot, displayCurrency: displayCurrency,
      exchangeRate: latestSnapshot.exchangeRate)

    var categoryValueLookup: [String: Decimal] = [:]
    var uncategorizedValue: Decimal = 0

    for (name, value) in catValues {
      if name.isEmpty {
        uncategorizedValue += value
      } else {
        categoryValueLookup[name, default: 0] += value
      }
    }

    // Build CategoryAllocation array for the calculator
    let categoryAllocations: [CategoryAllocation] = allCategories.map { category in
      CategoryAllocation(
        name: category.name,
        currentValue: categoryValueLookup[category.name] ?? 0,
        targetPercentage: category.targetAllocationPercentage
      )
    }

    // Calculate rebalancing actions (only categories with targets)
    let actions = RebalancingCalculator.calculateAdjustments(
      categories: categoryAllocations, totalValue: totalPortfolioValue)

    let currency = SettingsService.shared.mainCurrency

    suggestions = buildSuggestionRows(actions: actions, currency: currency)

    noTargetRows = buildNoTargetRows(
      categories: allCategories,
      categoryValues: categoryValueLookup)

    if uncategorizedValue > 0 {
      let percentage = CalculationService.categoryAllocation(
        categoryValue: uncategorizedValue, totalValue: totalPortfolioValue)
      uncategorizedRow = UncategorizedRowData(
        currentValue: uncategorizedValue,
        currentPercentage: percentage
      )
    }

    summaryTexts = buildSummaryTexts(actions: actions, currency: currency)
  }

  // MARK: - Private Helpers

  /// Maps calculator actions to display row data with localized action text.
  private func buildSuggestionRows(
    actions: [RebalancingAction], currency: String
  ) -> [RebalancingRowData] {
    actions.map { action in
      let actionText: String
      switch action.action {
      case .buy:
        actionText = String(
          localized: "Buy \(abs(action.adjustmentAmount).formatted(currency: currency))",
          table: "Rebalancing")

      case .sell:
        actionText = String(
          localized: "Sell \(abs(action.adjustmentAmount).formatted(currency: currency))",
          table: "Rebalancing")

      case .noAction:
        actionText = String(localized: "No action needed", table: "Rebalancing")
      }

      return RebalancingRowData(
        categoryName: action.categoryName,
        currentValue: action.currentValue,
        currentPercentage: action.currentPercentage,
        targetPercentage: action.targetPercentage,
        difference: action.adjustmentAmount,
        actionText: actionText,
        actionType: action.action
      )
    }
  }

  /// Builds rows for categories without target allocations.
  private func buildNoTargetRows(
    categories: [Category],
    categoryValues: [String: Decimal]
  ) -> [NoTargetRowData] {
    categories
      .filter { $0.targetAllocationPercentage == nil }
      .map { category in
        let value = categoryValues[category.name] ?? 0
        let percentage = CalculationService.categoryAllocation(
          categoryValue: value, totalValue: totalPortfolioValue)
        return NoTargetRowData(
          categoryName: category.name,
          currentValue: value,
          currentPercentage: percentage
        )
      }
      .sorted {
        $0.categoryName.localizedCaseInsensitiveCompare($1.categoryName) == .orderedAscending
      }
  }

  private func fetchAllSnapshots() -> [Snapshot] {
    let descriptor = FetchDescriptor<Snapshot>(sortBy: [SortDescriptor(\.date)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  private func fetchAllCategories() -> [Category] {
    let descriptor = FetchDescriptor<Category>(
      sortBy: [SortDescriptor(\.displayOrder), SortDescriptor(\.name)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  /// Builds human-readable summary texts pairing sell and buy categories
  /// using greedy matching to avoid overcounting.
  private func buildSummaryTexts(
    actions: [RebalancingAction], currency: String
  ) -> [String] {
    let sellActions = actions.filter { $0.action == .sell }
      .sorted { abs($0.adjustmentAmount) > abs($1.adjustmentAmount) }
    let buyActions = actions.filter { $0.action == .buy }
      .sorted { $0.adjustmentAmount > $1.adjustmentAmount }

    guard !sellActions.isEmpty && !buyActions.isEmpty else { return [] }

    // Track remaining capacity for each sell/buy
    var sellRemaining = sellActions.map { abs($0.adjustmentAmount) }
    var buyRemaining = buyActions.map { $0.adjustmentAmount }

    var texts: [String] = []
    for (sellIndex, sellAction) in sellActions.enumerated() {
      for (buyIndex, buyAction) in buyActions.enumerated() {
        let amount = min(sellRemaining[sellIndex], buyRemaining[buyIndex])
        if amount >= 1 {
          sellRemaining[sellIndex] -= amount
          buyRemaining[buyIndex] -= amount
          texts.append(
            String(
              localized:
                "Move \(amount.formatted(currency: currency)) from \(sellAction.categoryName) to \(buyAction.categoryName)",
              table: "Rebalancing"))
        }
      }
    }

    return texts
  }
}
