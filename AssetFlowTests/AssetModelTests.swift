//
//  AssetModelTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("Asset Model Tests")
@MainActor
struct AssetModelTests {

  // MARK: - Creation and Properties

  @Test("Asset initializes with name and empty platform by default")
  func testInitializesWithNameAndEmptyPlatform() {
    let asset = Asset(name: "AAPL")
    #expect(asset.name == "AAPL")
    #expect(asset.platform == "")
    #expect(asset.category == nil)
  }

  @Test("Asset initializes with name and platform")
  func testInitializesWithNameAndPlatform() {
    let asset = Asset(name: "AAPL", platform: "Firstrade")
    #expect(asset.name == "AAPL")
    #expect(asset.platform == "Firstrade")
  }

  @Test("Asset persists in SwiftData context")
  func testPersistsInContext() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "BTC", platform: "Binance")
    context.insert(asset)

    let descriptor = FetchDescriptor<Asset>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.count == 1)
    #expect(fetched.first?.name == "BTC")
    #expect(fetched.first?.platform == "Binance")
  }

  @Test("Each asset gets a unique UUID")
  func testEachAssetGetsUniqueUUID() {
    let a = Asset(name: "AAPL")
    let b = Asset(name: "GOOGL")
    #expect(a.id != b.id)
  }

  // MARK: - Normalized Identity

  @Test("normalizedName trims whitespace")
  func testNormalizedNameTrimsWhitespace() {
    let asset = Asset(name: "  AAPL  ")
    #expect(asset.normalizedName == "aapl")
  }

  @Test("normalizedName collapses multiple spaces")
  func testNormalizedNameCollapsesSpaces() {
    let asset = Asset(name: "My   Stock   Name")
    #expect(asset.normalizedName == "my stock name")
  }

  @Test("normalizedName lowercases")
  func testNormalizedNameLowercases() {
    let asset = Asset(name: "AAPL")
    #expect(asset.normalizedName == "aapl")
  }

  @Test("normalizedPlatform trims and lowercases")
  func testNormalizedPlatformTrimsAndLowercases() {
    let asset = Asset(name: "AAPL", platform: "  Firstrade  ")
    #expect(asset.normalizedPlatform == "firstrade")
  }

  @Test("normalizedPlatform collapses multiple spaces")
  func testNormalizedPlatformCollapsesSpaces() {
    let asset = Asset(name: "AAPL", platform: "My   Broker   App")
    #expect(asset.normalizedPlatform == "my broker app")
  }

  @Test("normalizedIdentity combines name and platform")
  func testNormalizedIdentityCombinesNameAndPlatform() {
    let asset = Asset(name: "AAPL", platform: "Firstrade")
    #expect(asset.normalizedIdentity == "aapl|firstrade")
  }

  @Test("normalizedIdentity matches case-insensitively")
  func testNormalizedIdentityMatchesCaseInsensitively() {
    let a = Asset(name: "AAPL", platform: "Firstrade")
    let b = Asset(name: "aapl", platform: "firstrade")
    #expect(a.normalizedIdentity == b.normalizedIdentity)
  }

  @Test("normalizedIdentity distinguishes different platforms")
  func testNormalizedIdentityDistinguishesPlatforms() {
    let a = Asset(name: "AAPL", platform: "Firstrade")
    let b = Asset(name: "AAPL", platform: "Schwab")
    #expect(a.normalizedIdentity != b.normalizedIdentity)
  }

  @Test("normalizedIdentity with empty platform")
  func testNormalizedIdentityWithEmptyPlatform() {
    let asset = Asset(name: "Gold")
    #expect(asset.normalizedIdentity == "gold|")
  }

  // MARK: - Category Relationship

  @Test("Asset can be assigned to a category")
  func testAssetCanBeAssignedToCategory() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let category = Category(name: "Stocks")
    let asset = Asset(name: "AAPL")
    context.insert(category)
    context.insert(asset)
    asset.category = category

    #expect(asset.category?.name == "Stocks")
    #expect(category.assets?.contains(where: { $0.name == "AAPL" }) == true)
  }

  @Test("Asset category can be set to nil")
  func testAssetCategoryCanBeSetToNil() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let category = Category(name: "Stocks")
    let asset = Asset(name: "AAPL")
    context.insert(category)
    context.insert(asset)
    asset.category = category
    asset.category = nil

    #expect(asset.category == nil)
  }

  // MARK: - Snapshot Asset Values Relationship

  @Test("Asset snapshotAssetValues starts empty")
  func testSnapshotAssetValuesStartsEmpty() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "AAPL")
    context.insert(asset)

    #expect(asset.snapshotAssetValues?.isEmpty ?? true)
  }
}
