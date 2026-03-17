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

/// Stateless service for currency conversion using exchange rates.
///
/// All methods gracefully degrade: if exchange rate is nil or conversion is unavailable,
/// values are returned unconverted.
enum CurrencyConversionService {

  /// Converts a value from one currency to another.
  ///
  /// Returns the original value if:
  /// - Currencies are the same
  /// - Exchange rate is nil
  /// - Rate data is missing for either currency
  static func convert(
    value: Decimal,
    from: String,
    to: String,
    using exchangeRate: ExchangeRate?
  ) -> Decimal {
    let fromLower = from.lowercased()
    let toLower = to.lowercased()

    guard fromLower != toLower else { return value }
    guard let exchangeRate else { return value }
    return exchangeRate.convert(value: value, from: fromLower, to: toLower) ?? value
  }

  /// Computes total portfolio value for a snapshot, converting each asset's value
  /// from its native currency to the display currency.
  static func totalValue(
    for snapshot: Snapshot,
    displayCurrency: String,
    exchangeRate: ExchangeRate?
  ) -> Decimal {
    let assetValues = snapshot.assetValues ?? []
    return assetValues.reduce(Decimal(0)) { sum, sav in
      let assetCurrency = sav.asset?.currency ?? ""
      let effectiveCurrency = assetCurrency.isEmpty ? displayCurrency : assetCurrency
      let converted = convert(
        value: sav.marketValue,
        from: effectiveCurrency,
        to: displayCurrency,
        using: exchangeRate
      )
      return sum + converted
    }
  }

  /// Computes net cash flow for a snapshot, converting each operation's amount
  /// from its currency to the display currency.
  static func netCashFlow(
    for snapshot: Snapshot,
    displayCurrency: String,
    exchangeRate: ExchangeRate?
  ) -> Decimal {
    let operations = snapshot.cashFlowOperations ?? []
    return operations.reduce(Decimal(0)) { sum, op in
      let opCurrency = op.currency.isEmpty ? displayCurrency : op.currency
      let converted = convert(
        value: op.amount,
        from: opCurrency,
        to: displayCurrency,
        using: exchangeRate
      )
      return sum + converted
    }
  }

  /// Groups asset values by category name, converting each to display currency.
  ///
  /// Assets without a category are grouped under an empty string key.
  static func categoryValues(
    for snapshot: Snapshot,
    displayCurrency: String,
    exchangeRate: ExchangeRate?
  ) -> [String: Decimal] {
    let assetValues = snapshot.assetValues ?? []
    var result: [String: Decimal] = [:]

    for sav in assetValues {
      let categoryName = sav.asset?.category?.name ?? ""
      let assetCurrency = sav.asset?.currency ?? ""
      let effectiveCurrency = assetCurrency.isEmpty ? displayCurrency : assetCurrency
      let converted = convert(
        value: sav.marketValue,
        from: effectiveCurrency,
        to: displayCurrency,
        using: exchangeRate
      )
      result[categoryName, default: Decimal(0)] += converted
    }

    return result
  }

  /// Checks whether conversion is possible between two currencies.
  static func canConvert(
    from: String,
    to: String,
    using exchangeRate: ExchangeRate?
  ) -> Bool {
    let fromLower = from.lowercased()
    let toLower = to.lowercased()

    guard fromLower != toLower else { return true }
    guard let exchangeRate else { return false }
    return exchangeRate.convert(value: Decimal(1), from: fromLower, to: toLower) != nil
  }
}
