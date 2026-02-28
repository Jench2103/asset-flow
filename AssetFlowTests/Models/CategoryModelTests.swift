//
//  CategoryModelTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("Category Model Tests")
@MainActor
struct CategoryModelTests {

  // MARK: - Creation and Properties

  @Test("Category initializes with name and UUID")
  func testInitializesWithNameAndUUID() {
    let category = Category(name: "Stocks")
    #expect(category.name == "Stocks")
    #expect(category.targetAllocationPercentage == nil)
    #expect(category.id != UUID(uuidString: "00000000-0000-0000-0000-000000000000"))
  }

  @Test("Category initializes with name and target allocation")
  func testInitializesWithTargetAllocation() {
    let category = Category(name: "Bonds", targetAllocationPercentage: Decimal(30))
    #expect(category.name == "Bonds")
    #expect(category.targetAllocationPercentage == Decimal(30))
  }

  @Test("Category persists in SwiftData context")
  func testPersistsInContext() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let category = Category(name: "Real Estate", targetAllocationPercentage: Decimal(20))
    context.insert(category)

    let descriptor = FetchDescriptor<AssetFlow.Category>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.count == 1)
    #expect(fetched.first?.name == "Real Estate")
    #expect(fetched.first?.targetAllocationPercentage == Decimal(20))
  }

  @Test("Category assets relationship starts empty")
  func testAssetsRelationshipStartsEmpty() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let category = Category(name: "Stocks")
    context.insert(category)

    #expect(category.assets?.isEmpty ?? true)
  }

  // MARK: - Target Allocation

  @Test("Target allocation accepts decimal precision")
  func testTargetAllocationAcceptsDecimalPrecision() throws {
    let value = try #require(Decimal(string: "33.333"))
    let category = Category(name: "Third", targetAllocationPercentage: value)
    #expect(category.targetAllocationPercentage == value)
  }

  @Test("Target allocation can be set to nil")
  func testTargetAllocationCanBeSetToNil() {
    let category = Category(name: "Stocks", targetAllocationPercentage: Decimal(50))
    category.targetAllocationPercentage = nil
    #expect(category.targetAllocationPercentage == nil)
  }

  // MARK: - Multiple Categories

  @Test("Multiple categories can be created independently")
  func testMultipleCategoriesCreatedIndependently() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let stocks = Category(name: "Stocks", targetAllocationPercentage: Decimal(60))
    let bonds = Category(name: "Bonds", targetAllocationPercentage: Decimal(30))
    let cash = Category(name: "Cash", targetAllocationPercentage: Decimal(10))

    context.insert(stocks)
    context.insert(bonds)
    context.insert(cash)

    let descriptor = FetchDescriptor<AssetFlow.Category>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.count == 3)
  }

}
