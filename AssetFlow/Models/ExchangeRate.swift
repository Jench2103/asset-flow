//
//  ExchangeRate.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/22.
//

import Foundation
import SwiftData

@Model
final class ExchangeRate {
  var baseCurrency: String
  var ratesJSON: Data
  var fetchDate: Date
  var isFallback: Bool

  @Relationship
  var snapshot: Snapshot?

  init(
    baseCurrency: String,
    ratesJSON: Data,
    fetchDate: Date,
    isFallback: Bool = false
  ) {
    self.baseCurrency = baseCurrency
    self.ratesJSON = ratesJSON
    self.fetchDate = fetchDate
    self.isFallback = isFallback
    self.snapshot = nil
  }

  /// Decoded rates dictionary from JSON
  var rates: [String: Double] {
    (try? JSONDecoder().decode([String: Double].self, from: ratesJSON)) ?? [:]
  }

  /// Convert a value from one currency to another using stored rates.
  ///
  /// Formula: `value / rates[from] * rates[to]`
  /// where `rates[baseCurrency]` is implicitly 1.0.
  ///
  /// - Parameters:
  ///   - value: The amount to convert
  ///   - from: Source currency code (lowercase)
  ///   - to: Target currency code (lowercase)
  /// - Returns: Converted value, or nil if rates are unavailable for either currency
  func convert(value: Decimal, from: String, to: String) -> Decimal? {
    let fromLower = from.lowercased()
    let toLower = to.lowercased()

    guard fromLower != toLower else { return value }

    let currentRates = rates

    // Get rate for source currency (base currency rate is implicitly 1.0)
    let fromRate: Double
    if fromLower == baseCurrency.lowercased() {
      fromRate = 1.0
    } else if let rate = currentRates[fromLower] {
      fromRate = rate
    } else {
      return nil
    }

    // Get rate for target currency (base currency rate is implicitly 1.0)
    let toRate: Double
    if toLower == baseCurrency.lowercased() {
      toRate = 1.0
    } else if let rate = currentRates[toLower] {
      toRate = rate
    } else {
      return nil
    }

    // Convert: value / fromRate * toRate
    let fromDecimal = Decimal(fromRate)
    let toDecimal = Decimal(toRate)

    guard fromDecimal != 0 else { return nil }

    return value / fromDecimal * toDecimal
  }
}
