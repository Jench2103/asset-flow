//
//  PriceHistoryManagementViewModelTests.swift
//  AssetFlowTests
//
//  Created by Claude on 2025/10/20.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("PriceHistoryManagementViewModel Tests")
@MainActor
struct PriceHistoryManagementViewModelTests {

  // MARK: - Helper

  private func createAsset(context: ModelContext) -> Asset {
    let asset = Asset(name: "Test Asset", assetType: .stock, currency: "USD")
    context.insert(asset)
    return asset
  }

  private func addPriceRecord(
    context: ModelContext, asset: Asset, daysAgo: Int, price: Decimal
  ) -> PriceHistory {
    let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    let record = PriceHistory(date: date, price: price, asset: asset)
    context.insert(record)
    return record
  }

  // MARK: - Init Tests

  @Test("Init sets default state")
  func testInit_DefaultState() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.recordToDelete == nil)
    #expect(viewModel.showingDeleteConfirmation == false)
    #expect(viewModel.showingLastRecordAlert == false)
  }

  // MARK: - Sorted History Tests

  @Test("Sorted price history returns sorted newest first")
  func testSortedPriceHistory_ReturnsSortedNewestFirst() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 10, price: 90)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 1, price: 110)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 5, price: 100)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)
    let sorted = viewModel.sortedPriceHistory

    #expect(sorted.count == 3)
    #expect(sorted[0].price == 110)
    #expect(sorted[1].price == 100)
    #expect(sorted[2].price == 90)
  }

  @Test("Sorted price history returns empty when no records")
  func testSortedPriceHistory_NoRecords_ReturnsEmpty() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.sortedPriceHistory.isEmpty)
  }

  // MARK: - Record Count Tests

  @Test("Record count returns correct count")
  func testRecordCount_ReturnsCorrectCount() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 5, price: 100)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 1, price: 110)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.recordCount == 2)
  }

  // MARK: - canDeleteRecords Tests

  @Test("canDeleteRecords returns false for single record")
  func testCanDeleteRecords_SingleRecord_ReturnsFalse() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 1, price: 100)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.canDeleteRecords == false)
  }

  @Test("canDeleteRecords returns true for multiple records")
  func testCanDeleteRecords_MultipleRecords_ReturnsTrue() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 5, price: 100)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 1, price: 110)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.canDeleteRecords == true)
  }

  @Test("canDeleteRecords returns false for no records")
  func testCanDeleteRecords_NoRecords_ReturnsFalse() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.canDeleteRecords == false)
  }

  // MARK: - Initiate Delete Tests

  @Test("Initiate delete with multiple records shows confirmation")
  func testInitiateDelete_MultipleRecords_ShowsConfirmation() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let record = addPriceRecord(
      context: context, asset: asset, daysAgo: 5, price: 100)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 1, price: 110)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(record: record)

    #expect(viewModel.recordToDelete?.id == record.id)
    #expect(viewModel.showingDeleteConfirmation == true)
    #expect(viewModel.showingLastRecordAlert == false)
  }

  @Test("Initiate delete with single record shows last record alert")
  func testInitiateDelete_SingleRecord_ShowsLastRecordAlert() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let record = addPriceRecord(
      context: context, asset: asset, daysAgo: 1, price: 100)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(record: record)

    #expect(viewModel.recordToDelete == nil)
    #expect(viewModel.showingDeleteConfirmation == false)
    #expect(viewModel.showingLastRecordAlert == true)
  }

  // MARK: - Confirm Delete Tests

  @Test("Confirm delete removes record")
  func testConfirmDelete_RemovesRecord() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let record = addPriceRecord(
      context: context, asset: asset, daysAgo: 5, price: 100)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 1, price: 110)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(record: record)
    viewModel.confirmDelete()

    let fetchDescriptor = FetchDescriptor<PriceHistory>()
    let records = try context.fetch(fetchDescriptor)
    #expect(records.count == 1)
    #expect(records.first?.price == 110)
  }

  @Test("Confirm delete resets state")
  func testConfirmDelete_ResetsState() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let record = addPriceRecord(
      context: context, asset: asset, daysAgo: 5, price: 100)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 1, price: 110)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(record: record)
    viewModel.confirmDelete()

    #expect(viewModel.recordToDelete == nil)
    #expect(viewModel.showingDeleteConfirmation == false)
  }

  @Test("Confirm delete with nil record does nothing")
  func testConfirmDelete_NilRecord_DoesNothing() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 1, price: 100)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)
    // Don't initiate delete, so recordToDelete is nil
    viewModel.confirmDelete()

    #expect(asset.priceHistory?.count == 1)
  }

  @Test("Confirm delete only removes target record")
  func testConfirmDelete_OnlyTargetRemoved() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let record1 = addPriceRecord(
      context: context, asset: asset, daysAgo: 10, price: 90)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 5, price: 100)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 1, price: 110)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(record: record1)
    viewModel.confirmDelete()

    let fetchDescriptor = FetchDescriptor<PriceHistory>()
    let records = try context.fetch(fetchDescriptor)
    #expect(records.count == 2)
    #expect(records.allSatisfy { $0.id != record1.id })
  }

  @Test("Confirm delete of latest record recalculates current price")
  func testConfirmDelete_LatestRecord_RecalculatesCurrentPrice() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 5, price: 90)
    let latestRecord = addPriceRecord(
      context: context, asset: asset, daysAgo: 1, price: 150)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(record: latestRecord)
    viewModel.confirmDelete()

    // Force SwiftData to process the deletion
    try context.save()

    // After deleting the latest (150), current price should fall back to 90
    #expect(asset.currentPrice == 90)
  }

  // MARK: - Cancel Delete Tests

  @Test("Cancel delete resets state")
  func testCancelDelete_ResetsState() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let record = addPriceRecord(
      context: context, asset: asset, daysAgo: 5, price: 100)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 1, price: 110)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(record: record)
    viewModel.cancelDelete()

    #expect(viewModel.recordToDelete == nil)
    #expect(viewModel.showingDeleteConfirmation == false)
  }

  @Test("Cancel delete preserves records")
  func testCancelDelete_PreservesRecords() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let record = addPriceRecord(
      context: context, asset: asset, daysAgo: 5, price: 100)
    _ = addPriceRecord(context: context, asset: asset, daysAgo: 1, price: 110)

    let viewModel = PriceHistoryManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(record: record)
    viewModel.cancelDelete()

    #expect(asset.priceHistory?.count == 2)
  }
}
