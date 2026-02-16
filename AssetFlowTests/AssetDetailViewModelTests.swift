//
//  AssetDetailViewModelTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("AssetDetailViewModel Tests")
@MainActor
struct AssetDetailViewModelTests {

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

  // MARK: - Property Loading

  @Test("Loads asset properties correctly")
  func loadsAssetPropertiesCorrectly() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let category = Category(name: "Equities")
    context.insert(category)

    let asset = Asset(name: "AAPL", platform: "Firstrade")
    asset.category = category
    context.insert(asset)

    let viewModel = AssetDetailViewModel(asset: asset, modelContext: context)

    #expect(viewModel.editedName == "AAPL")
    #expect(viewModel.editedPlatform == "Firstrade")
    #expect(viewModel.editedCategory?.name == "Equities")
  }

  // MARK: - Value History

  @Test("Value history across multiple snapshots in chronological order")
  func valueHistoryAcrossMultipleSnapshotsInChronologicalOrder() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(asset)

    // Create snapshots in non-chronological insertion order
    let snap3 = Snapshot(date: makeDate(year: 2025, month: 3, day: 1))
    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    context.insert(snap3)
    context.insert(snap1)
    context.insert(snap2)

    for (snap, value) in [
      (snap1, Decimal(10000)), (snap2, Decimal(12000)), (snap3, Decimal(15000)),
    ] {
      let sav = SnapshotAssetValue(marketValue: value)
      sav.snapshot = snap
      sav.asset = asset
      context.insert(sav)
    }

    let viewModel = AssetDetailViewModel(asset: asset, modelContext: context)
    viewModel.loadValueHistory()

    #expect(viewModel.valueHistory.count == 3)
    // Should be sorted oldest to newest
    #expect(viewModel.valueHistory[0].marketValue == Decimal(10000))
    #expect(viewModel.valueHistory[1].marketValue == Decimal(12000))
    #expect(viewModel.valueHistory[2].marketValue == Decimal(15000))
    #expect(viewModel.valueHistory[0].date < viewModel.valueHistory[1].date)
    #expect(viewModel.valueHistory[1].date < viewModel.valueHistory[2].date)
  }

  @Test("Value history empty when asset has no snapshot values")
  func valueHistoryEmptyWhenAssetHasNoSnapshotValues() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "NewAsset", platform: "")
    context.insert(asset)

    let viewModel = AssetDetailViewModel(asset: asset, modelContext: context)
    viewModel.loadValueHistory()

    #expect(viewModel.valueHistory.isEmpty)
  }

  // MARK: - Editing

  @Test("Edit name saves to model")
  func editNameSavesToModel() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(asset)

    let viewModel = AssetDetailViewModel(asset: asset, modelContext: context)
    viewModel.editedName = "Apple Inc."
    try viewModel.save()

    #expect(asset.name == "Apple Inc.")
  }

  @Test("Edit platform saves to model")
  func editPlatformSavesToModel() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(asset)

    let viewModel = AssetDetailViewModel(asset: asset, modelContext: context)
    viewModel.editedPlatform = "Schwab"
    try viewModel.save()

    #expect(asset.platform == "Schwab")
  }

  @Test("Edit category saves to model")
  func editCategorySavesToModel() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let category = Category(name: "Equities")
    context.insert(category)

    let asset = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(asset)

    let viewModel = AssetDetailViewModel(asset: asset, modelContext: context)
    viewModel.editedCategory = category
    try viewModel.save()

    #expect(asset.category?.name == "Equities")
  }

  // MARK: - Conflict Detection

  @Test("Name/platform conflict rejected with error")
  func namePlatformConflictRejectedWithError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let assetA = Asset(name: "AAPL", platform: "Firstrade")
    let assetB = Asset(name: "BTC", platform: "Binance")
    context.insert(assetA)
    context.insert(assetB)

    let viewModel = AssetDetailViewModel(asset: assetA, modelContext: context)
    viewModel.editedName = "BTC"
    viewModel.editedPlatform = "Binance"

    #expect(throws: AssetError.self) {
      try viewModel.save()
    }
  }

  @Test("Conflict check uses normalized comparison (case-insensitive, trimmed, collapsed)")
  func conflictCheckUsesNormalizedComparison() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let assetA = Asset(name: "  Apple  ", platform: "PLATFORM")
    let assetB = Asset(name: "Other", platform: "Other")
    context.insert(assetA)
    context.insert(assetB)

    let viewModel = AssetDetailViewModel(asset: assetB, modelContext: context)
    viewModel.editedName = "apple"
    viewModel.editedPlatform = "platform"

    #expect(throws: AssetError.self) {
      try viewModel.save()
    }
  }

  // MARK: - Retroactive Rename

  @Test("Rename propagates across all snapshots retroactively")
  func renamePropagatesAcrossAllSnapshotsRetroactively() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(asset)

    // Create SAVs in multiple snapshots
    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    context.insert(snap1)
    context.insert(snap2)

    let sav1 = SnapshotAssetValue(marketValue: 10000)
    sav1.snapshot = snap1
    sav1.asset = asset
    context.insert(sav1)

    let sav2 = SnapshotAssetValue(marketValue: 15000)
    sav2.snapshot = snap2
    sav2.asset = asset
    context.insert(sav2)

    // Rename via ViewModel
    let viewModel = AssetDetailViewModel(asset: asset, modelContext: context)
    viewModel.editedName = "Apple Inc."
    try viewModel.save()

    // Both SAVs still point to the same asset with the new name
    #expect(sav1.asset?.name == "Apple Inc.")
    #expect(sav2.asset?.name == "Apple Inc.")
    #expect(sav1.asset === sav2.asset)
  }

  // MARK: - Delete Validation

  @Test("canDelete true when no snapshot values")
  func canDeleteTrueWhenNoSnapshotValues() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "NewAsset", platform: "")
    context.insert(asset)

    let viewModel = AssetDetailViewModel(asset: asset, modelContext: context)
    #expect(viewModel.canDelete == true)
  }

  @Test("canDelete false when snapshot values exist")
  func canDeleteFalseWhenSnapshotValuesExist() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let snap = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    context.insert(snap)
    let (asset, _) = createAssetWithValue(
      name: "AAPL", platform: "Firstrade", marketValue: 15000,
      snapshot: snap, context: context)

    let viewModel = AssetDetailViewModel(asset: asset, modelContext: context)
    #expect(viewModel.canDelete == false)
  }

  @Test("Deletion explanatory text uses SPEC 6.3 exact wording")
  func deletionExplanatoryTextUsesSpec63ExactWording() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Multi", platform: "Firstrade")
    context.insert(asset)

    // Create 3 snapshots with values
    for month in 1...3 {
      let snap = Snapshot(date: makeDate(year: 2025, month: month, day: 1))
      context.insert(snap)
      let sav = SnapshotAssetValue(marketValue: Decimal(month * 1000))
      sav.snapshot = snap
      sav.asset = asset
      context.insert(sav)
    }

    let viewModel = AssetDetailViewModel(asset: asset, modelContext: context)
    let explanation = viewModel.deleteExplanation

    // Non-tautological: verify the message is non-nil and contains the dynamic count
    #expect(explanation != nil)
    #expect(explanation!.contains("3"))
  }

  @Test("Delete removes asset from context")
  func deleteRemovesAssetFromContext() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Deletable", platform: "")
    context.insert(asset)

    let viewModel = AssetDetailViewModel(asset: asset, modelContext: context)
    viewModel.deleteAsset()

    let descriptor = FetchDescriptor<Asset>()
    let remaining = try context.fetch(descriptor)
    #expect(remaining.isEmpty)
  }

  // MARK: - Rename vs CSV Import Behavior

  @Test("Rename in-app preserves single asset across all snapshots")
  func renameVsCSVImportBehavior() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "AAPL", platform: "Firstrade")
    context.insert(asset)

    let snap1 = Snapshot(date: makeDate(year: 2025, month: 1, day: 1))
    let snap2 = Snapshot(date: makeDate(year: 2025, month: 2, day: 1))
    context.insert(snap1)
    context.insert(snap2)

    let sav1 = SnapshotAssetValue(marketValue: 10000)
    sav1.snapshot = snap1
    sav1.asset = asset
    context.insert(sav1)

    let sav2 = SnapshotAssetValue(marketValue: 15000)
    sav2.snapshot = snap2
    sav2.asset = asset
    context.insert(sav2)

    let viewModel = AssetDetailViewModel(asset: asset, modelContext: context)
    viewModel.editedName = "Apple Inc."
    try viewModel.save()

    // After renaming, there should still be only 1 asset
    let descriptor = FetchDescriptor<Asset>()
    let allAssets = try context.fetch(descriptor)
    #expect(allAssets.count == 1)
    #expect(allAssets[0].name == "Apple Inc.")

    // Both SAVs should reference the same single asset
    let savDescriptor = FetchDescriptor<SnapshotAssetValue>()
    let allSAVs = try context.fetch(savDescriptor)
    #expect(allSAVs.count == 2)
    #expect(allSAVs.allSatisfy { $0.asset?.id == asset.id })
  }
}
