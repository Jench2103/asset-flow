//
//  PlatformDetailViewModelTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/17.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("PlatformDetailViewModel Tests")
@MainActor
struct PlatformDetailViewModelTests {

  // MARK: - Test Helpers

  private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar.current.date(from: components)!
  }

  private struct TestContext {
    let container: ModelContainer
    let context: ModelContext
  }

  private func makeTestContext() -> TestContext {
    let container = TestDataManager.createInMemoryContainer()
    return TestContext(container: container, context: container.mainContext)
  }

  @discardableResult
  private func createAssetWithValue(
    name: String,
    platform: String,
    category: AssetFlow.Category? = nil,
    marketValue: Decimal,
    snapshot: Snapshot,
    context: ModelContext
  ) -> (Asset, SnapshotAssetValue) {
    let asset = Asset(name: name, platform: platform)
    asset.category = category
    context.insert(asset)
    let sav = SnapshotAssetValue(marketValue: marketValue)
    sav.snapshot = snapshot
    sav.asset = asset
    context.insert(sav)
    return (asset, sav)
  }

  // MARK: - Asset Listing

  @Test("Lists assets for selected platform")
  func listsAssetsForSelectedPlatform() {
    let tc = makeTestContext()
    let context = tc.context

    let snap = Snapshot(date: makeDate(year: 2025, month: 6, day: 1))
    context.insert(snap)

    createAssetWithValue(
      name: "AAPL", platform: "Firstrade",
      marketValue: 5000, snapshot: snap, context: context)
    createAssetWithValue(
      name: "MSFT", platform: "Firstrade",
      marketValue: 3000, snapshot: snap, context: context)
    // Asset on a different platform — should be excluded
    createAssetWithValue(
      name: "BND", platform: "Vanguard",
      marketValue: 2000, snapshot: snap, context: context)

    let viewModel = PlatformDetailViewModel(
      platformName: "Firstrade", modelContext: context)
    viewModel.loadData()

    #expect(viewModel.assets.count == 2)
    #expect(viewModel.assets.allSatisfy { $0.asset.platform == "Firstrade" })
  }

  @Test("Assets sorted alphabetically")
  func assetsSortedAlphabetically() {
    let tc = makeTestContext()
    let context = tc.context

    let snap = Snapshot(date: makeDate(year: 2025, month: 6, day: 1))
    context.insert(snap)

    createAssetWithValue(
      name: "MSFT", platform: "Firstrade",
      marketValue: 3000, snapshot: snap, context: context)
    createAssetWithValue(
      name: "AAPL", platform: "Firstrade",
      marketValue: 5000, snapshot: snap, context: context)
    createAssetWithValue(
      name: "GOOG", platform: "Firstrade",
      marketValue: 2000, snapshot: snap, context: context)

    let viewModel = PlatformDetailViewModel(
      platformName: "Firstrade", modelContext: context)
    viewModel.loadData()

    #expect(viewModel.assets.count == 3)
    #expect(viewModel.assets[0].asset.name == "AAPL")
    #expect(viewModel.assets[1].asset.name == "GOOG")
    #expect(viewModel.assets[2].asset.name == "MSFT")
  }

  @Test("Latest value from composite snapshot")
  func latestValueFromCompositeSnapshot() {
    let tc = makeTestContext()
    let context = tc.context

    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    context.insert(snap1)
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    context.insert(snap2)

    let (asset, _) = createAssetWithValue(
      name: "AAPL", platform: "Firstrade",
      marketValue: 5000, snapshot: snap1, context: context)

    let sav2 = SnapshotAssetValue(marketValue: 7000)
    sav2.snapshot = snap2
    sav2.asset = asset
    context.insert(sav2)

    let viewModel = PlatformDetailViewModel(
      platformName: "Firstrade", modelContext: context)
    viewModel.loadData()

    #expect(viewModel.assets.count == 1)
    #expect(viewModel.assets[0].latestValue == 7000)
  }

  @Test("Total value sums assets on platform")
  func totalValueSumsAssetsOnPlatform() {
    let tc = makeTestContext()
    let context = tc.context

    let snap = Snapshot(date: makeDate(year: 2025, month: 6, day: 1))
    context.insert(snap)

    createAssetWithValue(
      name: "AAPL", platform: "Firstrade",
      marketValue: 5000, snapshot: snap, context: context)
    createAssetWithValue(
      name: "MSFT", platform: "Firstrade",
      marketValue: 3000, snapshot: snap, context: context)

    let viewModel = PlatformDetailViewModel(
      platformName: "Firstrade", modelContext: context)
    viewModel.loadData()

    #expect(viewModel.totalValue == 8000)
  }

  @Test("Assets from other platforms excluded")
  func assetsFromOtherPlatformsExcluded() {
    let tc = makeTestContext()
    let context = tc.context

    let snap = Snapshot(date: makeDate(year: 2025, month: 6, day: 1))
    context.insert(snap)

    createAssetWithValue(
      name: "AAPL", platform: "Firstrade",
      marketValue: 5000, snapshot: snap, context: context)
    createAssetWithValue(
      name: "BND", platform: "Vanguard",
      marketValue: 2000, snapshot: snap, context: context)
    createAssetWithValue(
      name: "BTC", platform: "Coinbase",
      marketValue: 10000, snapshot: snap, context: context)

    let viewModel = PlatformDetailViewModel(
      platformName: "Firstrade", modelContext: context)
    viewModel.loadData()

    #expect(viewModel.assets.count == 1)
    #expect(viewModel.assets[0].asset.name == "AAPL")
    #expect(viewModel.totalValue == 5000)
  }

  // MARK: - Value History

  @Test("Value history computed across snapshots")
  func valueHistoryComputedAcrossSnapshots() {
    let tc = makeTestContext()
    let context = tc.context

    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    context.insert(snap1)
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    context.insert(snap2)

    createAssetWithValue(
      name: "AAPL", platform: "Firstrade",
      marketValue: 5000, snapshot: snap1, context: context)
    createAssetWithValue(
      name: "AAPL", platform: "Firstrade",
      marketValue: 7000, snapshot: snap2, context: context)

    let viewModel = PlatformDetailViewModel(
      platformName: "Firstrade", modelContext: context)
    viewModel.loadData()

    #expect(viewModel.valueHistory.count == 2)
    #expect(viewModel.valueHistory[0].date == snap1.date)
    #expect(viewModel.valueHistory[0].totalValue == 5000)
    #expect(viewModel.valueHistory[1].date == snap2.date)
    #expect(viewModel.valueHistory[1].totalValue == 7000)
  }

  @Test("Value history includes carry-forward snapshots")
  func valueHistoryIncludesCarryForwardSnapshots() {
    let tc = makeTestContext()
    let context = tc.context

    // Snapshot 1: Firstrade has AAPL = 5000
    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    context.insert(snap1)
    createAssetWithValue(
      name: "AAPL", platform: "Firstrade",
      marketValue: 5000, snapshot: snap1, context: context)

    // Snapshot 2: Only Vanguard updated — Firstrade carries forward from snap1
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    context.insert(snap2)
    createAssetWithValue(
      name: "BND", platform: "Vanguard",
      marketValue: 3000, snapshot: snap2, context: context)

    let viewModel = PlatformDetailViewModel(
      platformName: "Firstrade", modelContext: context)
    viewModel.loadData()

    // Snap2: AAPL should carry forward from snap1 = 5000
    #expect(viewModel.valueHistory.count == 2)
    #expect(viewModel.valueHistory[1].date == snap2.date)
    #expect(viewModel.valueHistory[1].totalValue == 5000)
  }

  @Test("Value history shows zero for snapshots before platform existed")
  func valueHistoryShowsZeroForSnapshotsBeforePlatformExisted() {
    let tc = makeTestContext()
    let context = tc.context

    // Snapshot 1: Only Vanguard — Firstrade doesn't exist yet
    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    context.insert(snap1)
    createAssetWithValue(
      name: "BND", platform: "Vanguard",
      marketValue: 3000, snapshot: snap1, context: context)

    // Snapshot 2: Firstrade appears for the first time
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    context.insert(snap2)
    createAssetWithValue(
      name: "AAPL", platform: "Firstrade",
      marketValue: 5000, snapshot: snap2, context: context)

    let viewModel = PlatformDetailViewModel(
      platformName: "Firstrade", modelContext: context)
    viewModel.loadData()

    #expect(viewModel.valueHistory.count == 2)
    #expect(viewModel.valueHistory[0].date == snap1.date)
    #expect(viewModel.valueHistory[0].totalValue == 0)
    #expect(viewModel.valueHistory[1].date == snap2.date)
    #expect(viewModel.valueHistory[1].totalValue == 5000)
  }

  // MARK: - Rename

  @Test("Rename updates platformName and editedName")
  func renameUpdatesPlatformNameAndEditedName() throws {
    let tc = makeTestContext()
    let context = tc.context

    let asset = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(asset)

    let viewModel = PlatformDetailViewModel(
      platformName: "Firstrade", modelContext: context)
    viewModel.editedName = "Interactive Brokers"
    try viewModel.save()

    #expect(viewModel.platformName == "Interactive Brokers")
    #expect(viewModel.editedName == "Interactive Brokers")
    #expect(asset.platform == "Interactive Brokers")
  }

  @Test("Rename rejects empty name")
  func renameRejectsEmptyName() {
    let tc = makeTestContext()
    let context = tc.context

    let asset = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(asset)

    let viewModel = PlatformDetailViewModel(
      platformName: "Firstrade", modelContext: context)
    viewModel.editedName = "   "

    #expect(throws: PlatformError.emptyName) {
      try viewModel.save()
    }
  }

  @Test("Rename rejects duplicate platform name (case-insensitive)")
  func renameRejectsDuplicatePlatformNameCaseInsensitive() {
    let tc = makeTestContext()
    let context = tc.context

    let asset1 = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(asset1)
    let asset2 = Asset(name: "BND", platform: "Vanguard")
    context.insert(asset2)

    let viewModel = PlatformDetailViewModel(
      platformName: "Firstrade", modelContext: context)
    viewModel.editedName = "vanguard"

    #expect(throws: PlatformError.duplicateName("vanguard")) {
      try viewModel.save()
    }
  }

  @Test("Self-rename with different casing succeeds")
  func selfRenameWithDifferentCasingSucceeds() throws {
    let tc = makeTestContext()
    let context = tc.context

    let asset = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(asset)

    let viewModel = PlatformDetailViewModel(
      platformName: "Firstrade", modelContext: context)
    viewModel.editedName = "FIRSTRADE"
    try viewModel.save()

    #expect(viewModel.platformName == "FIRSTRADE")
    #expect(asset.platform == "FIRSTRADE")
  }
}
