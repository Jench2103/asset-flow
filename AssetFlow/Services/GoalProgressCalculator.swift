//
//  GoalProgressCalculator.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/28.
//

import Foundation

/// Calculator for financial goal progress metrics
///
/// Provides pure static functions for calculating:
/// - Achievement rate (percentage of goal reached)
/// - Distance to goal (remaining amount)
/// - Goal reached status
enum GoalProgressCalculator {

  /// Calculates the achievement rate as a percentage
  /// - Parameters:
  ///   - totalValue: Current total portfolio value
  ///   - goal: Target financial goal amount
  /// - Returns: Achievement percentage (0-100+), or 0 if goal is nil or zero
  static func calculateAchievementRate(totalValue: Decimal, goal: Decimal?) -> Decimal {
    guard let goal = goal, goal > 0 else { return 0 }
    return (totalValue / goal) * 100
  }

  /// Calculates the distance remaining to reach the goal
  /// - Parameters:
  ///   - totalValue: Current total portfolio value
  ///   - goal: Target financial goal amount
  /// - Returns: Positive if below goal, zero at goal, negative if above goal
  static func calculateDistanceToGoal(totalValue: Decimal, goal: Decimal?) -> Decimal {
    guard let goal = goal else { return 0 }
    return goal - totalValue
  }

  /// Checks whether the financial goal has been reached
  /// - Parameters:
  ///   - totalValue: Current total portfolio value
  ///   - goal: Target financial goal amount
  /// - Returns: True if total value equals or exceeds the goal
  static func isGoalReached(totalValue: Decimal, goal: Decimal?) -> Bool {
    guard let goal = goal else { return false }
    return totalValue >= goal
  }
}
