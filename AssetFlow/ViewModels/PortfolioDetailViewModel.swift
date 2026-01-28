//
//  PortfolioDetailViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/18.
//

import Foundation
import SwiftData
import SwiftUI

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
  private let exchangeRateService: ExchangeRateService

  /// Settings service for main currency
  private let settingsService: SettingsService

  /// Converted total value in main currency
  var totalValueInMainCurrency: Decimal = 0

  /// The main currency used for display
  var mainCurrency: String {
    settingsService.mainCurrency
  }

  /// Loading state for exchange rates
  var isLoadingRates: Bool {
    exchangeRateService.isLoading
  }

  /// Error message from exchange rate service, if any
  var exchangeRateError: String? {
    exchangeRateService.lastError
  }

  init(
    portfolio: Portfolio, modelContext: ModelContext,
    exchangeRateService: ExchangeRateService = .shared,
    settingsService: SettingsService = .shared
  ) {
    self.portfolio = portfolio
    self.modelContext = modelContext
    self.exchangeRateService = exchangeRateService
    self.settingsService = settingsService

    // Start fetching exchange rates.
    // Use [weak self] to avoid retaining the ViewModel — if it is deallocated
    // (e.g. during tests) the Task safely no-ops instead of accessing
    // destroyed SwiftData backing storage.
    Task { [weak self] in
      await self?.fetchExchangeRates()
      self?.calculateTotalValue()
    }
  }

  // MARK: - Computed Properties

  /// All assets belonging to this portfolio
  /// Fetches fresh data from SwiftData to ensure latest changes are included
  var assets: [Asset] {
    // Return the portfolio's assets directly from the relationship
    // This ensures we always get the current state including any recent deletions
    portfolio.assets ?? []
  }

  /// Number of assets in the portfolio
  var assetCount: Int {
    assets.count
  }

  // MARK: - Methods

  /// Fetch exchange rates and calculate total value
  func fetchExchangeRates() async {
    await exchangeRateService.fetchRates()
  }

  /// Calculate total value in main currency with currency conversion
  func calculateTotalValue() {
    // Use assets property which is always fetched fresh from SwiftData
    totalValueInMainCurrency = PortfolioValueCalculator.calculateTotalValue(
      for: assets,
      using: exchangeRateService.rates,
      targetCurrency: settingsService.mainCurrency,
      ratesBaseCurrency: exchangeRateService.baseCurrency
    )
  }

  /// Refresh exchange rates and recalculate
  func refresh() async {
    await fetchExchangeRates()
    calculateTotalValue()
  }
}
