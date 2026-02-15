//
//  AssetListViewModelTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("AssetListViewModel Tests")
@MainActor
struct AssetListViewModelTests {

  // MARK: - Test Helpers

  private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar.current.date(from: components)!
  }

  @discardableResult
  private func createAssetWithValue(
    name: String,
    platform: String,
    marketValue: Decimal,
    snapshot: Snapshot,
    context: ModelContext
  ) -> (Asset, SnapshotAssetValue) {
    let asset = Asset(name: name, platform: platform)
    context.insert(asset)
    let sav = SnapshotAssetValue(marketValue: marketValue)
    sav.snapshot = snapshot
    sav.asset = asset
    context.insert(sav)
    return (asset, sav)
  }

  private func allAssets(in groups: [AssetGroup]) -> [AssetRowData] {
    groups.flatMap { $0.assets }
  }

  // MARK: - Listing

  @Test("Lists all assets across groups")
  func listsAllAssets() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let assetA = Asset(name: "AAPL", platform: "Firstrade")
    let assetB = Asset(name: "BTC", platform: "Binance")
    let assetC = Asset(name: "ETH", platform: "Binance")
    context.insert(assetA)
    context.insert(assetB)
    context.insert(assetC)

    let viewModel = AssetListViewModel(modelContext: context)
    viewModel.loadAssets()

    let totalAssets = allAssets(in: viewModel.groups)
    #expect(totalAssets.count == 3)
  }

  // MARK: - Platform Grouping

  @Test("Groups assets by platform with alphabetical sort")
  func groupsByPlatformWithAlphabeticalSort() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let assetA = Asset(name: "AAPL", platform: "Firstrade")
    let assetB = Asset(name: "BTC", platform: "Binance")
    let assetC = Asset(name: "ETH", platform: "Binance")
    context.insert(assetA)
    context.insert(assetB)
    context.insert(assetC)

    let viewModel = AssetListViewModel(modelContext: context)
    viewModel.groupingMode = .byPlatform
    viewModel.loadAssets()

    #expect(viewModel.groups.count == 2)
    #expect(viewModel.groups[0].name == "Binance")
    #expect(viewModel.groups[1].name == "Firstrade")

    // Assets within Binance group sorted alphabetically
    let binanceAssets = viewModel.groups[0].assets
    #expect(binanceAssets.count == 2)
    #expect(binanceAssets[0].asset.name == "BTC")
    #expect(binanceAssets[1].asset.name == "ETH")
  }

  // MARK: - Category Grouping

  @Test("Groups assets by category with alphabetical sort")
  func groupsByCategoryWithAlphabeticalSort() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let bonds = Category(name: "Bonds")
    let equities = Category(name: "Equities")
    context.insert(bonds)
    context.insert(equities)

    let assetA = Asset(name: "AAPL", platform: "Firstrade")
    assetA.category = equities
    let assetB = Asset(name: "Treasury", platform: "Vanguard")
    assetB.category = bonds
    context.insert(assetA)
    context.insert(assetB)

    let viewModel = AssetListViewModel(modelContext: context)
    viewModel.groupingMode = .byCategory
    viewModel.loadAssets()

    #expect(viewModel.groups.count == 2)
    #expect(viewModel.groups[0].name == "Bonds")
    #expect(viewModel.groups[1].name == "Equities")
  }

  // MARK: - No Platform Group

  @Test("Assets without platform appear in (No Platform) group positioned last")
  func assetsWithoutPlatformInNoPlatformGroup() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let assetA = Asset(name: "AAPL", platform: "Firstrade")
    let assetB = Asset(name: "Gold", platform: "")
    context.insert(assetA)
    context.insert(assetB)

    let viewModel = AssetListViewModel(modelContext: context)
    viewModel.groupingMode = .byPlatform
    viewModel.loadAssets()

    #expect(viewModel.groups.count == 2)
    // "(No Platform)" should be last
    #expect(viewModel.groups[0].name == "Firstrade")
    #expect(viewModel.groups[1].name == String(localized: "(No Platform)", table: "Asset"))
    #expect(viewModel.groups[1].assets.count == 1)
    #expect(viewModel.groups[1].assets[0].asset.name == "Gold")
  }

  // MARK: - Uncategorized Group

  @Test("Assets without category appear in (Uncategorized) group positioned last")
  func assetsWithoutCategoryInUncategorizedGroup() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let equities = Category(name: "Equities")
    context.insert(equities)

    let assetA = Asset(name: "AAPL", platform: "Firstrade")
    assetA.category = equities
    let assetB = Asset(name: "Gold", platform: "")
    // assetB has no category
    context.insert(assetA)
    context.insert(assetB)

    let viewModel = AssetListViewModel(modelContext: context)
    viewModel.groupingMode = .byCategory
    viewModel.loadAssets()

    #expect(viewModel.groups.count == 2)
    #expect(viewModel.groups[0].name == "Equities")
    #expect(viewModel.groups[1].name == String(localized: "(Uncategorized)", table: "Asset"))
    #expect(viewModel.groups[1].assets.count == 1)
    #expect(viewModel.groups[1].assets[0].asset.name == "Gold")
  }

  // MARK: - Latest Value

  @Test("Latest value computed from most recent composite snapshot")
  func latestValueComputedFromMostRecentCompositeSnapshot() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    context.insert(snap1)
    let asset = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(asset)
    let sav1 = SnapshotAssetValue(marketValue: 10000)
    sav1.snapshot = snap1
    sav1.asset = asset
    context.insert(sav1)

    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    context.insert(snap2)
    let sav2 = SnapshotAssetValue(marketValue: 15000)
    sav2.snapshot = snap2
    sav2.asset = asset
    context.insert(sav2)

    let viewModel = AssetListViewModel(modelContext: context)
    viewModel.loadAssets()

    let rows = allAssets(in: viewModel.groups)
    #expect(rows.count == 1)
    #expect(rows[0].latestValue == Decimal(15000))
  }

  @Test("Latest value is nil when asset has no snapshot values")
  func latestValueNilWhenAssetHasNoSnapshotValues() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "NewAsset", platform: "")
    context.insert(asset)

    let viewModel = AssetListViewModel(modelContext: context)
    viewModel.loadAssets()

    let rows = allAssets(in: viewModel.groups)
    #expect(rows.count == 1)
    #expect(rows[0].latestValue == nil)
  }

  // MARK: - Deletion

  @Test("Delete succeeds when asset has no snapshot values")
  func deleteSucceedsWhenNoSnapshotValues() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Deletable", platform: "")
    context.insert(asset)

    let viewModel = AssetListViewModel(modelContext: context)
    try viewModel.deleteAsset(asset)

    let descriptor = FetchDescriptor<Asset>()
    let remaining = try context.fetch(descriptor)
    #expect(remaining.isEmpty)
  }

  @Test("Delete blocked when snapshot values exist")
  func deleteBlockedWhenSnapshotValuesExist() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let snap = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    context.insert(snap)
    let (asset, _) = createAssetWithValue(
      name: "AAPL", platform: "Firstrade", marketValue: 15000,
      snapshot: snap, context: context)

    let viewModel = AssetListViewModel(modelContext: context)

    #expect(throws: AssetError.self) {
      try viewModel.deleteAsset(asset)
    }
  }

  @Test("Delete blocked message includes snapshot count")
  func deleteBlockedMessageIncludesSnapshotCount() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Multi", platform: "Firstrade")
    context.insert(asset)

    // Create 3 snapshots with values for this asset
    for month in 1...3 {
      let snap = Snapshot(date: makeDate(year: 2025, month: month, day: 1))
      context.insert(snap)
      let sav = SnapshotAssetValue(marketValue: Decimal(month * 1000))
      sav.snapshot = snap
      sav.asset = asset
      context.insert(sav)
    }

    let viewModel = AssetListViewModel(modelContext: context)

    do {
      try viewModel.deleteAsset(asset)
      Issue.record("Expected AssetError.cannotDelete to be thrown")
    } catch let error as AssetError {
      #expect(error == .cannotDelete(snapshotCount: 3))
    }
  }

  @Test("Delete counts distinct snapshots, not SAV records")
  func deleteCountsDistinctSnapshotsNotSAVRecords() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Multi", platform: "Firstrade")
    context.insert(asset)

    // Create 1 snapshot with 2 SAVs for the same asset
    // (simulating e.g. two value entries in the same snapshot)
    let snap = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    context.insert(snap)

    let sav1 = SnapshotAssetValue(marketValue: 1000)
    sav1.snapshot = snap
    sav1.asset = asset
    context.insert(sav1)

    let sav2 = SnapshotAssetValue(marketValue: 2000)
    sav2.snapshot = snap
    sav2.asset = asset
    context.insert(sav2)

    let viewModel = AssetListViewModel(modelContext: context)

    do {
      try viewModel.deleteAsset(asset)
      Issue.record("Expected AssetError.cannotDelete to be thrown")
    } catch let error as AssetError {
      // Should count 1 distinct snapshot, not 2 SAV records
      #expect(error == .cannotDelete(snapshotCount: 1))
    }
  }

  // MARK: - Empty State

  @Test("Empty state when no assets exist")
  func emptyStateWhenNoAssets() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = AssetListViewModel(modelContext: context)
    viewModel.loadAssets()

    #expect(viewModel.groups.isEmpty)
  }
}
