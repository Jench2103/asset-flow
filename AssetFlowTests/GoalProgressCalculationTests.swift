//
//  GoalProgressCalculationTests.swift
//  AssetFlowTests
//
//  Created by Claude on 2025/10/28.
//

import Foundation
import Testing

@testable import AssetFlow

@Suite("Goal Progress Calculation Tests")
struct GoalProgressCalculationTests {

  // MARK: - Achievement Rate

  @Test("Achievement rate is 0% when total value is 0")
  func testAchievementRateZeroWhenValueIsZero() {
    let rate = GoalProgressCalculator.calculateAchievementRate(totalValue: 0, goal: 100000)
    #expect(rate == 0)
  }

  @Test("Achievement rate is 50% when at half of goal")
  func testAchievementRateFiftyPercentAtHalf() {
    let rate = GoalProgressCalculator.calculateAchievementRate(totalValue: 50000, goal: 100000)
    #expect(rate == 50)
  }

  @Test("Achievement rate is 100% when goal is reached exactly")
  func testAchievementRateHundredPercentAtGoal() {
    let rate = GoalProgressCalculator.calculateAchievementRate(totalValue: 100000, goal: 100000)
    #expect(rate == 100)
  }

  @Test("Achievement rate exceeds 100% when above goal")
  func testAchievementRateExceedsHundredWhenAboveGoal() {
    let rate = GoalProgressCalculator.calculateAchievementRate(totalValue: 150000, goal: 100000)
    #expect(rate == 150)
  }

  @Test("Achievement rate is 0% when goal is nil")
  func testAchievementRateZeroWhenNoGoal() {
    let rate = GoalProgressCalculator.calculateAchievementRate(totalValue: 50000, goal: nil)
    #expect(rate == 0)
  }

  @Test("Achievement rate is 0% when goal is zero (prevents division by zero)")
  func testAchievementRateZeroWhenGoalIsZero() {
    let rate = GoalProgressCalculator.calculateAchievementRate(totalValue: 50000, goal: 0)
    #expect(rate == 0)
  }

  // MARK: - Distance to Goal

  @Test("Distance to goal is positive when below target")
  func testDistancePositiveWhenBelowTarget() {
    let distance = GoalProgressCalculator.calculateDistanceToGoal(totalValue: 40000, goal: 100000)
    #expect(distance == 60000)
  }

  @Test("Distance to goal is zero when at target")
  func testDistanceZeroWhenAtTarget() {
    let distance = GoalProgressCalculator.calculateDistanceToGoal(totalValue: 100000, goal: 100000)
    #expect(distance == 0)
  }

  @Test("Distance to goal is negative when above target")
  func testDistanceNegativeWhenAboveTarget() {
    let distance = GoalProgressCalculator.calculateDistanceToGoal(totalValue: 120000, goal: 100000)
    #expect(distance == -20000)
  }

  @Test("Distance to goal is 0 when goal is nil")
  func testDistanceZeroWhenNoGoal() {
    let distance = GoalProgressCalculator.calculateDistanceToGoal(totalValue: 50000, goal: nil)
    #expect(distance == 0)
  }

  // MARK: - Is Goal Reached

  @Test("isGoalReached is true when total value equals goal")
  func testIsGoalReachedWhenEqual() {
    let reached = GoalProgressCalculator.isGoalReached(totalValue: 100000, goal: 100000)
    #expect(reached == true)
  }

  @Test("isGoalReached is true when total value exceeds goal")
  func testIsGoalReachedWhenExceeds() {
    let reached = GoalProgressCalculator.isGoalReached(totalValue: 150000, goal: 100000)
    #expect(reached == true)
  }

  @Test("isGoalReached is false when below goal")
  func testIsGoalReachedFalseWhenBelow() {
    let reached = GoalProgressCalculator.isGoalReached(totalValue: 50000, goal: 100000)
    #expect(reached == false)
  }

  @Test("isGoalReached is false when goal is nil")
  func testIsGoalReachedFalseWhenNoGoal() {
    let reached = GoalProgressCalculator.isGoalReached(totalValue: 50000, goal: nil)
    #expect(reached == false)
  }

  // MARK: - Decimal Precision

  @Test("Achievement rate handles decimal precision correctly")
  func testAchievementRateDecimalPrecision() {
    let rate = GoalProgressCalculator.calculateAchievementRate(
      totalValue: Decimal(string: "33333.33")!,
      goal: Decimal(string: "100000")!)
    // Should be approximately 33.33333%
    #expect(rate > 33 && rate < 34)
  }
}
