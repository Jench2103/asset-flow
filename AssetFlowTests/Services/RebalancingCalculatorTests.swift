//
//  RebalancingCalculatorTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation
import Testing

@testable import AssetFlow

@Suite("RebalancingCalculator Tests")
@MainActor
struct RebalancingCalculatorTests {

  // MARK: - Balanced Portfolio

  @Test("Balanced portfolio shows no action")
  func testBalancedPortfolio() {
    let categories = [
      CategoryAllocation(
        name: "Stocks", currentValue: Decimal(50000), targetPercentage: Decimal(50)),
      CategoryAllocation(
        name: "Bonds", currentValue: Decimal(50000), targetPercentage: Decimal(50)),
    ]

    let result = RebalancingCalculator.calculateAdjustments(
      categories: categories, totalValue: Decimal(100000))

    #expect(result.count == 2)
    #expect(result.allSatisfy { $0.action == .noAction })
  }

  // MARK: - Overweight Category

  @Test("Overweight category shows sell action")
  func testOverweightCategory() {
    let categories = [
      CategoryAllocation(
        name: "Stocks", currentValue: Decimal(70000), targetPercentage: Decimal(50)),
      CategoryAllocation(
        name: "Bonds", currentValue: Decimal(30000), targetPercentage: Decimal(50)),
    ]

    let result = RebalancingCalculator.calculateAdjustments(
      categories: categories, totalValue: Decimal(100000))

    let stocks = result.first(where: { $0.categoryName == "Stocks" })
    #expect(stocks?.action == .sell)
    #expect(stocks?.adjustmentAmount == Decimal(-20000))

    let bonds = result.first(where: { $0.categoryName == "Bonds" })
    #expect(bonds?.action == .buy)
    #expect(bonds?.adjustmentAmount == Decimal(20000))
  }

  // MARK: - Underweight Category

  @Test("Underweight category shows buy action")
  func testUnderweightCategory() {
    let categories = [
      CategoryAllocation(name: "Bonds", currentValue: Decimal(10000), targetPercentage: Decimal(30))
    ]

    let result = RebalancingCalculator.calculateAdjustments(
      categories: categories, totalValue: Decimal(100000))

    #expect(result.count == 1)
    #expect(result[0].action == .buy)
    #expect(result[0].adjustmentAmount == Decimal(20000))
  }

  // MARK: - Threshold

  @Test("Adjustment under $1 threshold shows no action")
  func testThresholdNoAction() {
    let categories = [
      CategoryAllocation(
        name: "Stocks", currentValue: Decimal(string: "50000.50")!,
        targetPercentage: Decimal(50))
    ]

    let result = RebalancingCalculator.calculateAdjustments(
      categories: categories, totalValue: Decimal(100000))

    // Target value = 50000, current = 50000.50, adjustment = -0.50 (under $1)
    #expect(result[0].action == .noAction)
  }

  // MARK: - Multiple Categories

  @Test("Multiple categories with mixed adjustments sorted by magnitude")
  func testMultipleCategoriesSortedByMagnitude() {
    let categories = [
      CategoryAllocation(
        name: "Stocks", currentValue: Decimal(60000), targetPercentage: Decimal(50)),
      CategoryAllocation(
        name: "Bonds", currentValue: Decimal(20000), targetPercentage: Decimal(30)),
      CategoryAllocation(name: "Cash", currentValue: Decimal(20000), targetPercentage: Decimal(20)),
    ]

    let result = RebalancingCalculator.calculateAdjustments(
      categories: categories, totalValue: Decimal(100000))

    #expect(result.count == 3)
    // Stocks: 60000 -> 50000 = -10000
    // Bonds: 20000 -> 30000 = +10000
    // Cash: 20000 -> 20000 = 0
    #expect(result[0].categoryName == "Stocks" || result[0].categoryName == "Bonds")
    #expect(abs(result[0].adjustmentAmount) >= abs(result[1].adjustmentAmount))
    #expect(abs(result[1].adjustmentAmount) >= abs(result[2].adjustmentAmount))
  }

  // MARK: - Categories Without Target

  @Test("Categories without target percentage are excluded")
  func testCategoriesWithoutTargetExcluded() {
    let categories = [
      CategoryAllocation(
        name: "Stocks", currentValue: Decimal(50000), targetPercentage: Decimal(50)),
      CategoryAllocation(name: "No Target", currentValue: Decimal(50000), targetPercentage: nil),
    ]

    let result = RebalancingCalculator.calculateAdjustments(
      categories: categories, totalValue: Decimal(100000))

    #expect(result.count == 1)
    #expect(result[0].categoryName == "Stocks")
  }

  // MARK: - Edge Cases

  @Test("Zero total value returns empty actions")
  func testZeroTotalValue() {
    let categories = [
      CategoryAllocation(name: "Stocks", currentValue: Decimal(0), targetPercentage: Decimal(50))
    ]

    let result = RebalancingCalculator.calculateAdjustments(
      categories: categories, totalValue: Decimal(0))

    #expect(result.isEmpty)
  }

  @Test("Current percentage is calculated correctly")
  func testCurrentPercentageCalculated() {
    let categories = [
      CategoryAllocation(
        name: "Stocks", currentValue: Decimal(75000), targetPercentage: Decimal(50))
    ]

    let result = RebalancingCalculator.calculateAdjustments(
      categories: categories, totalValue: Decimal(100000))

    #expect(result[0].currentPercentage == Decimal(75))
    #expect(result[0].targetPercentage == Decimal(50))
  }

  @Test("Empty categories returns empty actions")
  func testEmptyCategories() {
    let result = RebalancingCalculator.calculateAdjustments(
      categories: [], totalValue: Decimal(100000))

    #expect(result.isEmpty)
  }
}
