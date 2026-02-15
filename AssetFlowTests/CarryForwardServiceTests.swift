//
//  CarryForwardServiceTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("CarryForwardService Tests")
@MainActor
struct CarryForwardServiceTests {

  // MARK: - Test Helpers

  private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar.current.date(from: components)!
  }

  private func linkAssetValue(
    _ value: SnapshotAssetValue, to snapshot: Snapshot, asset: Asset
  ) {
    value.snapshot = snapshot
    value.asset = asset
  }

  // MARK: - Single Snapshot (No Carry-Forward)

  @Test("Single snapshot returns only direct values")
  func testSingleSnapshotReturnsDirectValues() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let snapshot = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    let apple = Asset(name: "AAPL", platform: "Firstrade")
    let value = SnapshotAssetValue(marketValue: Decimal(15000))

    context.insert(snapshot)
    context.insert(apple)
    context.insert(value)
    linkAssetValue(value, to: snapshot, asset: apple)

    let result = CarryForwardService.compositeValues(
      for: snapshot, allSnapshots: [snapshot], allAssetValues: [value])

    #expect(result.count == 1)
    #expect(result[0].marketValue == Decimal(15000))
    #expect(result[0].isCarriedForward == false)
    #expect(result[0].sourceSnapshotDate == nil)
  }

  @Test("First snapshot has nothing to carry forward")
  func testFirstSnapshotHasNothingToCarryForward() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let snapshot = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    context.insert(snapshot)

    let result = CarryForwardService.compositeValues(
      for: snapshot, allSnapshots: [snapshot], allAssetValues: [])

    #expect(result.isEmpty)
  }

  // MARK: - Two Snapshots With Carry-Forward

  @Test("Second snapshot carries forward missing platform from first")
  func testCarryForwardMissingPlatform() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Snapshot 1: AAPL on Firstrade, BTC on Binance
    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    let apple = Asset(name: "AAPL", platform: "Firstrade")
    let btc = Asset(name: "BTC", platform: "Binance")
    let val1 = SnapshotAssetValue(marketValue: Decimal(15000))
    let val2 = SnapshotAssetValue(marketValue: Decimal(50000))

    context.insert(snap1)
    context.insert(apple)
    context.insert(btc)
    context.insert(val1)
    context.insert(val2)
    linkAssetValue(val1, to: snap1, asset: apple)
    linkAssetValue(val2, to: snap1, asset: btc)

    // Snapshot 2: only AAPL on Firstrade (Binance missing)
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    let val3 = SnapshotAssetValue(marketValue: Decimal(16000))
    context.insert(snap2)
    context.insert(val3)
    linkAssetValue(val3, to: snap2, asset: apple)

    let allValues = [val1, val2, val3]
    let result = CarryForwardService.compositeValues(
      for: snap2, allSnapshots: [snap1, snap2], allAssetValues: allValues)

    #expect(result.count == 2)

    let directValues = result.filter { !$0.isCarriedForward }
    let carriedValues = result.filter { $0.isCarriedForward }

    #expect(directValues.count == 1)
    #expect(directValues[0].marketValue == Decimal(16000))

    #expect(carriedValues.count == 1)
    #expect(carriedValues[0].marketValue == Decimal(50000))
    #expect(carriedValues[0].asset.name == "BTC")
    #expect(carriedValues[0].sourceSnapshotDate == snap1.date)
  }

  // MARK: - Platform Present Prevents Asset-Level Carry-Forward

  @Test("Platform present in current snapshot blocks carry-forward for that platform")
  func testPlatformPresentBlocksCarryForward() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Snapshot 1: AAPL and GOOGL on Firstrade
    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    let apple = Asset(name: "AAPL", platform: "Firstrade")
    let google = Asset(name: "GOOGL", platform: "Firstrade")
    let val1 = SnapshotAssetValue(marketValue: Decimal(15000))
    let val2 = SnapshotAssetValue(marketValue: Decimal(20000))

    context.insert(snap1)
    context.insert(apple)
    context.insert(google)
    context.insert(val1)
    context.insert(val2)
    linkAssetValue(val1, to: snap1, asset: apple)
    linkAssetValue(val2, to: snap1, asset: google)

    // Snapshot 2: only AAPL on Firstrade (GOOGL sold)
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    let val3 = SnapshotAssetValue(marketValue: Decimal(16000))
    context.insert(snap2)
    context.insert(val3)
    linkAssetValue(val3, to: snap2, asset: apple)

    let allValues = [val1, val2, val3]
    let result = CarryForwardService.compositeValues(
      for: snap2, allSnapshots: [snap1, snap2], allAssetValues: allValues)

    // Only AAPL should appear -- GOOGL is NOT carried forward because
    // platform "Firstrade" is present in snap2
    #expect(result.count == 1)
    #expect(result[0].asset.name == "AAPL")
    #expect(result[0].isCarriedForward == false)
  }

  // MARK: - Multiple Platforms Mixed

  @Test("Multiple platforms: some present, some carried forward")
  func testMultiplePlatformsMixed() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Snapshot 1: assets on Firstrade, Binance, and Chase
    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    let apple = Asset(name: "AAPL", platform: "Firstrade")
    let btc = Asset(name: "BTC", platform: "Binance")
    let savings = Asset(name: "Savings", platform: "Chase")

    context.insert(snap1)
    context.insert(apple)
    context.insert(btc)
    context.insert(savings)

    let v1 = SnapshotAssetValue(marketValue: Decimal(15000))
    let v2 = SnapshotAssetValue(marketValue: Decimal(50000))
    let v3 = SnapshotAssetValue(marketValue: Decimal(20000))
    context.insert(v1)
    context.insert(v2)
    context.insert(v3)
    linkAssetValue(v1, to: snap1, asset: apple)
    linkAssetValue(v2, to: snap1, asset: btc)
    linkAssetValue(v3, to: snap1, asset: savings)

    // Snapshot 2: only Firstrade updated
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    let v4 = SnapshotAssetValue(marketValue: Decimal(16000))
    context.insert(snap2)
    context.insert(v4)
    linkAssetValue(v4, to: snap2, asset: apple)

    let allValues = [v1, v2, v3, v4]
    let result = CarryForwardService.compositeValues(
      for: snap2, allSnapshots: [snap1, snap2], allAssetValues: allValues)

    #expect(result.count == 3)

    let direct = result.filter { !$0.isCarriedForward }
    let carried = result.filter { $0.isCarriedForward }

    #expect(direct.count == 1)
    #expect(direct[0].asset.name == "AAPL")

    #expect(carried.count == 2)
    let carriedNames = Set(carried.map { $0.asset.name })
    #expect(carriedNames.contains("BTC"))
    #expect(carriedNames.contains("Savings"))
  }

  // MARK: - Three Snapshots: Carry-Forward Uses Most Recent

  @Test("Carry-forward uses most recent prior snapshot for a platform")
  func testCarryForwardUsesMostRecentPrior() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let btc = Asset(name: "BTC", platform: "Binance")
    let apple = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(btc)
    context.insert(apple)

    // Snapshot 1: BTC at 40000
    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    let v1 = SnapshotAssetValue(marketValue: Decimal(40000))
    context.insert(snap1)
    context.insert(v1)
    linkAssetValue(v1, to: snap1, asset: btc)

    // Snapshot 2: BTC at 50000, AAPL at 15000
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    let v2 = SnapshotAssetValue(marketValue: Decimal(50000))
    let v3 = SnapshotAssetValue(marketValue: Decimal(15000))
    context.insert(snap2)
    context.insert(v2)
    context.insert(v3)
    linkAssetValue(v2, to: snap2, asset: btc)
    linkAssetValue(v3, to: snap2, asset: apple)

    // Snapshot 3: only AAPL (Binance missing)
    let snap3 = Snapshot(date: makeDate(year: 2025, month: 3, day: 1))
    let v4 = SnapshotAssetValue(marketValue: Decimal(16000))
    context.insert(snap3)
    context.insert(v4)
    linkAssetValue(v4, to: snap3, asset: apple)

    let allValues = [v1, v2, v3, v4]
    let result = CarryForwardService.compositeValues(
      for: snap3, allSnapshots: [snap1, snap2, snap3], allAssetValues: allValues)

    let carried = result.filter { $0.isCarriedForward }
    #expect(carried.count == 1)
    #expect(carried[0].asset.name == "BTC")
    // Should carry forward from snap2 (50000), not snap1 (40000)
    #expect(carried[0].marketValue == Decimal(50000))
    #expect(carried[0].sourceSnapshotDate == snap2.date)
  }

  // MARK: - Empty Snapshot

  @Test("Empty snapshot carries forward all platforms from prior")
  func testEmptySnapshotCarriesForwardAll() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let apple = Asset(name: "AAPL", platform: "Firstrade")
    let btc = Asset(name: "BTC", platform: "Binance")
    context.insert(apple)
    context.insert(btc)

    // Snapshot 1: both platforms
    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    let v1 = SnapshotAssetValue(marketValue: Decimal(15000))
    let v2 = SnapshotAssetValue(marketValue: Decimal(50000))
    context.insert(snap1)
    context.insert(v1)
    context.insert(v2)
    linkAssetValue(v1, to: snap1, asset: apple)
    linkAssetValue(v2, to: snap1, asset: btc)

    // Snapshot 2: empty
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    context.insert(snap2)

    let allValues = [v1, v2]
    let result = CarryForwardService.compositeValues(
      for: snap2, allSnapshots: [snap1, snap2], allAssetValues: allValues)

    #expect(result.count == 2)
    #expect(result.allSatisfy { $0.isCarriedForward })
  }

  // MARK: - Composite Total Value

  @Test("Composite total value sums direct and carried forward values")
  func testCompositeTotalValue() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let apple = Asset(name: "AAPL", platform: "Firstrade")
    let btc = Asset(name: "BTC", platform: "Binance")
    context.insert(apple)
    context.insert(btc)

    // Snapshot 1: BTC at 50000
    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    let v1 = SnapshotAssetValue(marketValue: Decimal(50000))
    context.insert(snap1)
    context.insert(v1)
    linkAssetValue(v1, to: snap1, asset: btc)

    // Snapshot 2: AAPL at 16000 (BTC carried forward)
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    let v2 = SnapshotAssetValue(marketValue: Decimal(16000))
    context.insert(snap2)
    context.insert(v2)
    linkAssetValue(v2, to: snap2, asset: apple)

    let allValues = [v1, v2]
    let total = CarryForwardService.compositeTotalValue(
      for: snap2, allSnapshots: [snap1, snap2], allAssetValues: allValues)

    #expect(total == Decimal(66000))
  }

  // MARK: - Assets Without Platform

  @Test("Assets with empty platform are treated as a distinct platform group")
  func testEmptyPlatformAsDistinctGroup() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let gold = Asset(name: "Gold", platform: "")
    let apple = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(gold)
    context.insert(apple)

    // Snapshot 1: both assets
    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    let v1 = SnapshotAssetValue(marketValue: Decimal(5000))
    let v2 = SnapshotAssetValue(marketValue: Decimal(15000))
    context.insert(snap1)
    context.insert(v1)
    context.insert(v2)
    linkAssetValue(v1, to: snap1, asset: gold)
    linkAssetValue(v2, to: snap1, asset: apple)

    // Snapshot 2: only Firstrade
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    let v3 = SnapshotAssetValue(marketValue: Decimal(16000))
    context.insert(snap2)
    context.insert(v3)
    linkAssetValue(v3, to: snap2, asset: apple)

    let allValues = [v1, v2, v3]
    let result = CarryForwardService.compositeValues(
      for: snap2, allSnapshots: [snap1, snap2], allAssetValues: allValues)

    #expect(result.count == 2)
    let carried = result.filter { $0.isCarriedForward }
    #expect(carried.count == 1)
    #expect(carried[0].asset.name == "Gold")
  }

  // MARK: - Multiple Assets Same Platform Carried Together

  @Test("All assets from a missing platform are carried forward together")
  func testAllAssetsFromMissingPlatformCarried() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let btc = Asset(name: "BTC", platform: "Binance")
    let eth = Asset(name: "ETH", platform: "Binance")
    let apple = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(btc)
    context.insert(eth)
    context.insert(apple)

    // Snapshot 1: all three
    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    let v1 = SnapshotAssetValue(marketValue: Decimal(50000))
    let v2 = SnapshotAssetValue(marketValue: Decimal(3000))
    let v3 = SnapshotAssetValue(marketValue: Decimal(15000))
    context.insert(snap1)
    context.insert(v1)
    context.insert(v2)
    context.insert(v3)
    linkAssetValue(v1, to: snap1, asset: btc)
    linkAssetValue(v2, to: snap1, asset: eth)
    linkAssetValue(v3, to: snap1, asset: apple)

    // Snapshot 2: only Firstrade
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    let v4 = SnapshotAssetValue(marketValue: Decimal(16000))
    context.insert(snap2)
    context.insert(v4)
    linkAssetValue(v4, to: snap2, asset: apple)

    let allValues = [v1, v2, v3, v4]
    let result = CarryForwardService.compositeValues(
      for: snap2, allSnapshots: [snap1, snap2], allAssetValues: allValues)

    let carried = result.filter { $0.isCarriedForward }
    #expect(carried.count == 2)
    let carriedNames = Set(carried.map { $0.asset.name })
    #expect(carriedNames == Set(["BTC", "ETH"]))
  }
}
