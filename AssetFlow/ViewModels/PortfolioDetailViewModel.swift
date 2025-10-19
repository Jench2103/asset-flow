//
//  PortfolioDetailViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/18.
//

import Foundation
import SwiftData

/// ViewModel for the Portfolio Detail screen
///
/// Manages the display of a portfolio's assets and calculates aggregated values.
@Observable
@MainActor
final class PortfolioDetailViewModel {
  /// The portfolio being displayed
  let portfolio: Portfolio

  /// The model context for data operations
  let modelContext: ModelContext

  /// Exchange rate service for currency conversion
  private let exchangeRateService = ExchangeRateService.shared

  /// Converted total value in USD
  var totalValueInUSD: Decimal = 0

  /// Refresh trigger to force view updates when assets change
  var refreshTrigger = UUID()

  /// Loading state for exchange rates
  var isLoadingRates: Bool {
    exchangeRateService.isLoading
  }

  /// Error message from exchange rate service, if any
  var exchangeRateError: String? {
    exchangeRateService.lastError
  }

  init(portfolio: Portfolio, modelContext: ModelContext) {
    self.portfolio = portfolio
    self.modelContext = modelContext

    // Start fetching exchange rates
    Task {
      await fetchExchangeRates()
      calculateTotalValue()
    }
  }

  // MARK: - Computed Properties

  /// All assets belonging to this portfolio
  var assets: [Asset] {
    portfolio.assets ?? []
  }

  /// Number of assets in the portfolio
  var assetCount: Int {
    portfolio.assetCount
  }

  // MARK: - Methods

  /// Fetch exchange rates and calculate total value
  func fetchExchangeRates() async {
    await exchangeRateService.fetchRates()
  }

  /// Calculate total value in USD with currency conversion
  func calculateTotalValue() {
    // Fetch fresh assets from the portfolio relationship to ensure we have latest data
    let currentAssets = portfolio.assets ?? []
    totalValueInUSD = PortfolioValueCalculator.calculateTotalValue(
      for: currentAssets,
      using: exchangeRateService.rates,
      targetCurrency: "USD",
      ratesBaseCurrency: exchangeRateService.baseCurrency
    )
  }

  /// Refresh the view by notifying observers of changes
  func refreshAssets() {
    // Update the refresh trigger to notify SwiftUI of changes
    refreshTrigger = UUID()
  }

  /// Refresh exchange rates and recalculate
  func refresh() async {
    await fetchExchangeRates()
    calculateTotalValue()
  }
}
