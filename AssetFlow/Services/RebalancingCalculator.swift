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

/// Input data for rebalancing calculation.
struct CategoryAllocation {
  let name: String
  let currentValue: Decimal
  let targetPercentage: Decimal?
}

/// The action type for a rebalancing adjustment.
enum RebalancingActionType {
  case buy
  case sell
  case noAction
}

/// A single rebalancing adjustment recommendation.
struct RebalancingAction {
  let categoryName: String
  let currentValue: Decimal
  let currentPercentage: Decimal
  let targetPercentage: Decimal
  let adjustmentAmount: Decimal
  let action: RebalancingActionType
}

/// Rebalancing calculator service (SPEC Section 11).
///
/// Pure calculation -- does NOT modify stored data.
/// Only categories with target allocations are included in results.
enum RebalancingCalculator {

  /// Minimum adjustment threshold (SPEC 11.4: adjustments under $1 = "No action needed").
  private static let minimumThreshold = Decimal(1)

  /// Calculates rebalancing adjustments for all categories with targets.
  ///
  /// - Parameters:
  ///   - categories: Current category allocations (may include categories without targets).
  ///   - totalValue: Total composite portfolio value.
  /// - Returns: Array of rebalancing actions, sorted by absolute adjustment magnitude (largest first).
  static func calculateAdjustments(
    categories: [CategoryAllocation],
    totalValue: Decimal
  ) -> [RebalancingAction] {
    guard totalValue > 0 else { return [] }

    var actions: [RebalancingAction] = []

    for category in categories {
      guard let target = category.targetPercentage else { continue }

      let currentPercentage = category.currentValue / totalValue * 100
      let targetValue = totalValue * target / 100
      let adjustment = targetValue - category.currentValue

      let action: RebalancingActionType
      if abs(adjustment) < minimumThreshold {
        action = .noAction
      } else if adjustment > 0 {
        action = .buy
      } else {
        action = .sell
      }

      actions.append(
        RebalancingAction(
          categoryName: category.name,
          currentValue: category.currentValue,
          currentPercentage: currentPercentage,
          targetPercentage: target,
          adjustmentAmount: adjustment,
          action: action
        ))
    }

    // Sort by absolute adjustment magnitude, largest first
    actions.sort { abs($0.adjustmentAmount) > abs($1.adjustmentAmount) }

    return actions
  }
}
