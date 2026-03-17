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

/// Financial calculation service for portfolio metrics.
///
/// All methods are pure functions operating on Decimal values.
/// Returns nil for edge cases where calculation is undefined (SPEC Section 10.7).
enum CalculationService {

  /// Calculates simple growth rate between two values (SPEC Section 10.3).
  ///
  /// Formula: `(endValue - beginValue) / beginValue`
  ///
  /// - Returns: Growth rate as a decimal (e.g., 0.10 for 10%), or nil if
  ///   beginning value is zero or negative.
  static func growthRate(beginValue: Decimal, endValue: Decimal) -> Decimal? {
    guard beginValue > 0 else { return nil }
    return (endValue - beginValue) / beginValue
  }

  /// Calculates Modified Dietz return (SPEC Section 10.4).
  ///
  /// Formula: `R = (EMV - BMV - CF) / (BMV + sum(wi * CFi))`
  /// Where `wi = (totalDays - daysSinceStart) / totalDays`
  ///
  /// - Parameters:
  ///   - beginValue: Beginning composite portfolio value (BMV).
  ///   - endValue: Ending composite portfolio value (EMV).
  ///   - cashFlows: Array of (amount, daysSinceStart) tuples for intermediate cash flows.
  ///   - totalDays: Total calendar days in the period.
  /// - Returns: Modified Dietz return as a decimal, or nil if denominator is <= 0
  ///   or beginning value is zero/negative.
  static func modifiedDietzReturn(
    beginValue: Decimal,
    endValue: Decimal,
    cashFlows: [(amount: Decimal, daysSinceStart: Int)],
    totalDays: Int
  ) -> Decimal? {
    guard beginValue > 0, totalDays > 0 else { return nil }

    let totalCashFlow = cashFlows.reduce(Decimal(0)) { $0 + $1.amount }

    let weightedCashFlow = cashFlows.reduce(Decimal(0)) { sum, cf in
      let weight = Decimal(totalDays - cf.daysSinceStart) / Decimal(totalDays)
      return sum + weight * cf.amount
    }

    let denominator = beginValue + weightedCashFlow
    guard denominator > 0 else { return nil }

    return (endValue - beginValue - totalCashFlow) / denominator
  }

  /// Calculates cumulative time-weighted return by chaining period returns (SPEC Section 10.5).
  ///
  /// Formula: `TWR = (1 + r1) * (1 + r2) * ... * (1 + rn) - 1`
  ///
  /// - Parameter periodReturns: Array of Modified Dietz returns for consecutive periods.
  /// - Returns: Cumulative TWR as a decimal.
  static func cumulativeTWR(periodReturns: [Decimal]) -> Decimal {
    let product = periodReturns.reduce(Decimal(1)) { $0 * (1 + $1) }
    return product - 1
  }

  /// Calculates compound annual growth rate (SPEC Section 10.6).
  ///
  /// Formula: `CAGR = (endValue / beginValue) ^ (1 / years) - 1`
  ///
  /// - Parameters:
  ///   - beginValue: Beginning portfolio value.
  ///   - endValue: Ending portfolio value.
  ///   - years: Number of years (can be fractional).
  /// - Returns: CAGR as a decimal, or nil if beginning value is zero/negative
  ///   or years is zero/negative.
  static func cagr(
    beginValue: Decimal, endValue: Decimal, years: Double
  ) -> Decimal? {
    guard beginValue > 0, endValue > 0, years > 0 else { return nil }
    let ratio = NSDecimalNumber(decimal: endValue / beginValue).doubleValue
    let result = pow(ratio, 1.0 / years) - 1.0
    return Decimal(result)
  }

  /// Calculates category allocation percentage (SPEC Section 10.2).
  ///
  /// Formula: `categoryValue / totalValue * 100`
  ///
  /// - Returns: Allocation percentage, or 0 if total value is zero.
  static func categoryAllocation(
    categoryValue: Decimal, totalValue: Decimal
  ) -> Decimal {
    guard totalValue > 0 else { return 0 }
    return categoryValue / totalValue * 100
  }
}
