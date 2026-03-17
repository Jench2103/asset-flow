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
