//
//  CategoryUniquenessTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/16.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("Category Uniqueness Constraints")
@MainActor
struct CategoryUniquenessTests {

  @Test("Category enforces unique name constraint at database level — duplicate upserts")
  func categoryEnforcesDatabaseUniqueness() throws {
    // Setup in-memory container
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Create first category
    let category1 = Category(name: "Equities", targetAllocationPercentage: nil)
    context.insert(category1)
    try context.save()

    // Attempt to create duplicate category (exact same name)
    let category2 = Category(name: "Equities", targetAllocationPercentage: Decimal(50))
    context.insert(category2)
    try context.save()

    // With #Unique constraint, should only have 1 category (upsert behavior)
    let descriptor = FetchDescriptor<AssetFlow.Category>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.count == 1)
  }
}
