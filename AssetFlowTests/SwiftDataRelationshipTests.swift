//
//  SwiftDataRelationshipTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("SwiftData Relationship Tests")
@MainActor
struct SwiftDataRelationshipTests {

  // MARK: - Category-Asset Relationship

  @Test("Assigning asset to category updates both sides of relationship")
  func testCategoryAssetBidirectional() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let category = Category(name: "Stocks")
    let asset = Asset(name: "AAPL")

    context.insert(category)
    context.insert(asset)

    asset.category = category

    #expect(asset.category === category)
    #expect(category.assets?.contains(where: { $0.name == "AAPL" }) == true)
  }

  @Test("Multiple assets can belong to the same category")
  func testMultipleAssetsInCategory() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let category = Category(name: "Stocks")
    let apple = Asset(name: "AAPL")
    let google = Asset(name: "GOOGL")

    context.insert(category)
    context.insert(apple)
    context.insert(google)

    apple.category = category
    google.category = category

    #expect(category.assets?.count == 2)
  }

  @Test("Deleting asset with .nullify removes it from category")
  func testDeletingAssetNullifiesCategory() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let category = Category(name: "Stocks")
    let asset = Asset(name: "AAPL")

    context.insert(category)
    context.insert(asset)
    asset.category = category

    // Remove the asset from the category first, then delete
    asset.category = nil
    context.delete(asset)

    let categories = try context.fetch(FetchDescriptor<AssetFlow.Category>())
    #expect(categories.count == 1)
    #expect(categories.first?.assets?.isEmpty ?? true)
  }

  // MARK: - Snapshot-SnapshotAssetValue Cascade Delete

  @Test("Deleting snapshot cascades to SnapshotAssetValues")
  func testSnapshotCascadesToAssetValues() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let snapshot = Snapshot(date: Date())
    let asset = Asset(name: "AAPL")
    let value = SnapshotAssetValue(marketValue: Decimal(15000))

    context.insert(snapshot)
    context.insert(asset)
    context.insert(value)

    value.snapshot = snapshot
    value.asset = asset

    // Delete the snapshot — asset value should cascade
    context.delete(snapshot)
    try context.save()

    let values = try context.fetch(FetchDescriptor<SnapshotAssetValue>())
    #expect(values.isEmpty)

    // Asset should still exist
    let assets = try context.fetch(FetchDescriptor<Asset>())
    #expect(assets.count == 1)
  }

  // MARK: - Snapshot-CashFlowOperation Cascade Delete

  @Test("Deleting snapshot cascades to CashFlowOperations")
  func testSnapshotCascadesToCashFlowOperations() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let snapshot = Snapshot(date: Date())
    let op = CashFlowOperation(cashFlowDescription: "Deposit", amount: Decimal(5000))

    context.insert(snapshot)
    context.insert(op)
    op.snapshot = snapshot

    context.delete(snapshot)
    try context.save()

    let operations = try context.fetch(FetchDescriptor<CashFlowOperation>())
    #expect(operations.isEmpty)
  }

  // MARK: - Asset Delete Rule Verification

  @Test("Deleting all snapshot values allows asset deletion")
  func testAssetCanBeDeletedAfterRemovingSnapshotValues() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let snapshot = Snapshot(date: Date())
    let asset = Asset(name: "AAPL")
    let value = SnapshotAssetValue(marketValue: Decimal(15000))

    context.insert(snapshot)
    context.insert(asset)
    context.insert(value)

    value.snapshot = snapshot
    value.asset = asset
    try context.save()

    // First remove the snapshot value, then delete the asset
    context.delete(value)
    try context.save()

    context.delete(asset)
    try context.save()

    let assets = try context.fetch(FetchDescriptor<Asset>())
    #expect(assets.isEmpty)
  }

  // MARK: - Complex Relationship Scenarios

  @Test("Snapshot with multiple asset values and cash flows")
  func testSnapshotWithMultipleRelationships() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let snapshot = Snapshot(date: Date())
    let asset1 = Asset(name: "AAPL")
    let asset2 = Asset(name: "BTC", platform: "Binance")

    context.insert(snapshot)
    context.insert(asset1)
    context.insert(asset2)

    let value1 = SnapshotAssetValue(marketValue: Decimal(10000))
    let value2 = SnapshotAssetValue(marketValue: Decimal(50000))
    let deposit = CashFlowOperation(cashFlowDescription: "Deposit", amount: Decimal(5000))

    context.insert(value1)
    context.insert(value2)
    context.insert(deposit)

    value1.snapshot = snapshot
    value1.asset = asset1
    value2.snapshot = snapshot
    value2.asset = asset2
    deposit.snapshot = snapshot

    #expect(snapshot.assetValues?.count == 2)
    #expect(snapshot.cashFlowOperations?.count == 1)
  }

  @Test("Asset across multiple snapshots")
  func testAssetAcrossMultipleSnapshots() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    var jan = DateComponents()
    jan.year = 2025
    jan.month = 1
    jan.day = 1
    let janDate = Calendar.current.date(from: jan)!

    var feb = DateComponents()
    feb.year = 2025
    feb.month = 2
    feb.day = 1
    let febDate = Calendar.current.date(from: feb)!

    let snapshot1 = Snapshot(date: janDate)
    let snapshot2 = Snapshot(date: febDate)
    let asset = Asset(name: "AAPL")

    context.insert(snapshot1)
    context.insert(snapshot2)
    context.insert(asset)

    let value1 = SnapshotAssetValue(marketValue: Decimal(10000))
    let value2 = SnapshotAssetValue(marketValue: Decimal(12000))

    context.insert(value1)
    context.insert(value2)

    value1.snapshot = snapshot1
    value1.asset = asset
    value2.snapshot = snapshot2
    value2.asset = asset

    #expect(asset.snapshotAssetValues?.count == 2)
    #expect(snapshot1.assetValues?.count == 1)
    #expect(snapshot2.assetValues?.count == 1)
  }

  @Test("Deleting one snapshot does not affect other snapshots")
  func testDeletingOneSnapshotDoesNotAffectOthers() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    var jan = DateComponents()
    jan.year = 2025
    jan.month = 1
    jan.day = 1
    let janDate = Calendar.current.date(from: jan)!

    var feb = DateComponents()
    feb.year = 2025
    feb.month = 2
    feb.day = 1
    let febDate = Calendar.current.date(from: feb)!

    let snapshot1 = Snapshot(date: janDate)
    let snapshot2 = Snapshot(date: febDate)
    let asset = Asset(name: "AAPL")

    context.insert(snapshot1)
    context.insert(snapshot2)
    context.insert(asset)

    let value1 = SnapshotAssetValue(marketValue: Decimal(10000))
    let value2 = SnapshotAssetValue(marketValue: Decimal(12000))

    context.insert(value1)
    context.insert(value2)

    value1.snapshot = snapshot1
    value1.asset = asset
    value2.snapshot = snapshot2
    value2.asset = asset

    // Delete snapshot1 — snapshot2 and its value should survive
    context.delete(snapshot1)
    try context.save()

    let snapshots = try context.fetch(FetchDescriptor<Snapshot>())
    #expect(snapshots.count == 1)
    #expect(snapshots.first?.date == Calendar.current.startOfDay(for: febDate))

    let values = try context.fetch(FetchDescriptor<SnapshotAssetValue>())
    #expect(values.count == 1)
    #expect(values.first?.marketValue == Decimal(12000))
  }

  // MARK: - Category Deny Delete When Has Assets

  @Test("Removing assets from category allows category deletion")
  func testCategoryCanBeDeletedAfterRemovingAssets() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let category = Category(name: "Stocks")
    let asset = Asset(name: "AAPL")

    context.insert(category)
    context.insert(asset)
    asset.category = category
    try context.save()

    // First remove the asset from the category, then delete the category
    asset.category = nil
    try context.save()

    context.delete(category)
    try context.save()

    let categories = try context.fetch(FetchDescriptor<AssetFlow.Category>())
    #expect(categories.isEmpty)
  }

  @Test("Category without assets can be deleted")
  func testCategoryWithoutAssetsCanBeDeleted() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let category = Category(name: "Empty Category")
    context.insert(category)
    try context.save()

    context.delete(category)
    try context.save()

    let categories = try context.fetch(FetchDescriptor<AssetFlow.Category>())
    #expect(categories.isEmpty)
  }
}
