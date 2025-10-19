//
//  PortfolioValueCalculator.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/19.
//

import Foundation

/// Service for calculating portfolio values with currency conversion
///
/// This service is NOT marked as @MainActor, allowing it to be used from any context.
/// It performs pure calculations without requiring main thread access.
struct PortfolioValueCalculator {

  /// Calculate total portfolio value with currency conversion
  /// - Parameters:
  ///   - assets: Array of assets in the portfolio
  ///   - exchangeRates: Dictionary of exchange rates (currency code -> rate relative to base)
  ///   - targetCurrency: The currency to convert to (default: "USD")
  ///   - ratesBaseCurrency: The base currency that exchange rates are relative to (default: "USD")
  /// - Returns: Total portfolio value in the target currency
  static func calculateTotalValue(
    for assets: [Asset],
    using exchangeRates: [String: Decimal],
    targetCurrency: String = "USD",
    ratesBaseCurrency: String = "USD"
  ) -> Decimal {
    var total: Decimal = 0

    for asset in assets {
      let valueInAssetCurrency = asset.currentValue
      let convertedValue = ExchangeRateService.convert(
        amount: valueInAssetCurrency,
        from: asset.currency,
        to: targetCurrency,
        using: exchangeRates,
        baseCurrency: ratesBaseCurrency
      )
      total += convertedValue
    }

    return total
  }

}
