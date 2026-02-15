//
//  AssetUniquenessTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/16.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("Asset Uniqueness Constraints")
@MainActor
struct AssetUniquenessTests {

  @Test("Asset enforces unique (name, platform) constraint at database level — duplicate upserts")
  func assetEnforcesDatabaseUniqueness() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Create first asset
    let asset1 = Asset(name: "AAPL", platform: "Interactive Brokers")
    context.insert(asset1)
    try context.save()

    // Attempt duplicate (same name AND platform)
    let asset2 = Asset(name: "AAPL", platform: "Interactive Brokers")
    context.insert(asset2)
    try context.save()

    // With #Unique constraint, should only have 1 asset (upsert behavior)
    let descriptor = FetchDescriptor<AssetFlow.Asset>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.count == 1)
  }

  @Test("Asset allows same name on different platforms")
  func assetAllowsSameNameDifferentPlatform() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Same asset name, different platforms - should be allowed
    let asset1 = Asset(name: "AAPL", platform: "Interactive Brokers")
    let asset2 = Asset(name: "AAPL", platform: "Schwab")

    context.insert(asset1)
    context.insert(asset2)
    try context.save()

    // Both should exist as separate records
    let descriptor = FetchDescriptor<AssetFlow.Asset>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.count == 2)

    // Verify they have different persistent IDs
    #expect(asset1.persistentModelID != asset2.persistentModelID)
  }
}
