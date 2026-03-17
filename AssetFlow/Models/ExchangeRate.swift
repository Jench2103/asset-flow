//  AssetFlow — snapshot-based portfolio management for macOS.
//  Copyright (C) 2026 Jen-Chien Chang
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
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

  @Transient
  private var _cachedRates: [String: Double]?

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

  /// Decoded rates dictionary from JSON (cached after first access).
  var rates: [String: Double] {
    if let cached = _cachedRates {
      return cached
    }
    let decoded = (try? JSONDecoder().decode([String: Double].self, from: ratesJSON)) ?? [:]
    _cachedRates = decoded
    return decoded
  }

  /// Updates rate data in-place and clears the decoded cache.
  func updateRates(baseCurrency: String, ratesJSON: Data, fetchDate: Date) {
    self.baseCurrency = baseCurrency
    self.ratesJSON = ratesJSON
    self.fetchDate = fetchDate
    self.isFallback = false
    self._cachedRates = nil
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
