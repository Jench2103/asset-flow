//
//  AssetCategoryRelationshipTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/16.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("Asset Category Relationship Delete Rules")
@MainActor
struct AssetCategoryRelationshipTests {

  @Test("Deleting a category nullifies asset.category references")
  func deletingCategoryNullifiesAssetReferences() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Create category and asset
    let equities = Category(name: "Equities", targetAllocationPercentage: Decimal(60))
    let apple = Asset(name: "AAPL", platform: "Interactive Brokers")
    apple.category = equities

    context.insert(equities)
    context.insert(apple)
    try context.save()

    // Verify relationship established
    #expect(apple.category?.name == "Equities")

    // Delete the category
    context.delete(equities)
    try context.save()

    // Verify: Asset still exists, but category is nil (nullify behavior)
    #expect(apple.category == nil)

    // Verify asset wasn't cascade-deleted
    let assets = try context.fetch(FetchDescriptor<AssetFlow.Asset>())
    #expect(assets.count == 1)
    #expect(assets.first?.name == "AAPL")
  }

  @Test("Deleting an asset does not delete the category")
  func deletingAssetDoesNotDeleteCategory() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let equities = Category(name: "Equities", targetAllocationPercentage: Decimal(60))
    let apple = Asset(name: "AAPL", platform: "Interactive Brokers")
    apple.category = equities

    context.insert(equities)
    context.insert(apple)
    try context.save()

    // Delete the asset
    context.delete(apple)
    try context.save()

    // Verify: Category still exists (not cascade-deleted)
    let categories = try context.fetch(FetchDescriptor<AssetFlow.Category>())
    #expect(categories.count == 1)
    #expect(categories.first?.name == "Equities")
  }
}
