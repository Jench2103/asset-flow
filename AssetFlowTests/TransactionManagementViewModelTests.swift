//
//  TransactionManagementViewModelTests.swift
//  AssetFlowTests
//
//  Created by Claude on 2026/1/27.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("TransactionManagementViewModel Tests", .serialized)
@MainActor
struct TransactionManagementViewModelTests {

  // MARK: - Helpers

  private func createAsset(context: ModelContext) -> Asset {
    let asset = Asset(name: "Test Asset", assetType: .stock, currency: "USD")
    context.insert(asset)
    return asset
  }

  @discardableResult
  private func addTransaction(
    context: ModelContext,
    asset: Asset,
    type: TransactionType = .buy,
    daysAgo: Int,
    quantity: Decimal = 10,
    pricePerUnit: Decimal = 100,
    totalAmount: Decimal = 1000
  ) -> Transaction {
    let date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
    let transaction = Transaction(
      transactionType: type,
      transactionDate: date,
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      totalAmount: totalAmount,
      currency: asset.currency,
      asset: asset
    )
    context.insert(transaction)
    return transaction
  }

  // MARK: - Init Tests

  @Test("Init sets default state with no pending deletion")
  func testInit_DefaultState() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.transactionToDelete == nil)
    #expect(viewModel.showingDeleteConfirmation == false)
    #expect(viewModel.deletionError == nil)
    #expect(viewModel.showingDeletionError == false)
  }

  // MARK: - Sorted Transactions Tests

  @Test("Sorted transactions returns sorted newest first")
  func testSortedTransactions_ReturnsSortedNewestFirst() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    addTransaction(
      context: context, asset: asset, daysAgo: 10, quantity: 5, pricePerUnit: 90, totalAmount: 450)
    addTransaction(
      context: context, asset: asset, daysAgo: 1, quantity: 3, pricePerUnit: 110, totalAmount: 330)
    addTransaction(
      context: context, asset: asset, daysAgo: 5, quantity: 7, pricePerUnit: 100, totalAmount: 700)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)
    let sorted = viewModel.sortedTransactions

    #expect(sorted.count == 3)
    #expect(sorted[0].quantity == 3)
    #expect(sorted[1].quantity == 7)
    #expect(sorted[2].quantity == 5)
  }

  @Test("Sorted transactions with no transactions returns empty")
  func testSortedTransactions_NoTransactions_ReturnsEmpty() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.sortedTransactions.isEmpty)
  }

  // MARK: - Transaction Count Tests

  @Test("Transaction count returns correct count")
  func testTransactionCount_ReturnsCorrectCount() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    addTransaction(context: context, asset: asset, daysAgo: 5)
    addTransaction(context: context, asset: asset, daysAgo: 1)
    addTransaction(context: context, asset: asset, daysAgo: 3)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.transactionCount == 3)
  }

  @Test("Transaction count with no transactions returns zero")
  func testTransactionCount_NoTransactions_ReturnsZero() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.transactionCount == 0)
  }

  // MARK: - canDelete Tests

  @Test("canDelete returns true for sell transaction (removing it increases quantity)")
  func testCanDelete_SellTransaction_ReturnsTrue() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    addTransaction(context: context, asset: asset, type: .buy, daysAgo: 10, quantity: 10)
    let sellTransaction = addTransaction(
      context: context, asset: asset, type: .sell, daysAgo: 5, quantity: 5)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.canDelete(transaction: sellTransaction) == true)
  }

  @Test("canDelete returns true for transferOut transaction (removing it increases quantity)")
  func testCanDelete_TransferOutTransaction_ReturnsTrue() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    addTransaction(context: context, asset: asset, type: .buy, daysAgo: 10, quantity: 10)
    let transferOut = addTransaction(
      context: context, asset: asset, type: .transferOut, daysAgo: 5, quantity: 3)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.canDelete(transaction: transferOut) == true)
  }

  @Test("canDelete returns true for buy when resulting quantity >= 0")
  func testCanDelete_BuyTransaction_QuantityRemainsSafe_ReturnsTrue() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let buyTransaction = addTransaction(
      context: context, asset: asset, type: .buy, daysAgo: 10, quantity: 10)
    addTransaction(context: context, asset: asset, type: .buy, daysAgo: 5, quantity: 5)

    // Current quantity = 15, deleting buy(10) → quantity = 5, which is >= 0
    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.canDelete(transaction: buyTransaction) == true)
  }

  @Test("canDelete returns false for buy when resulting quantity < 0")
  func testCanDelete_BuyTransaction_WouldCauseNegativeQuantity_ReturnsFalse() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let buyTransaction = addTransaction(
      context: context, asset: asset, type: .buy, daysAgo: 10, quantity: 10)
    addTransaction(context: context, asset: asset, type: .sell, daysAgo: 5, quantity: 8)

    // Current quantity = 2, deleting buy(10) → quantity = 2 - 10 = -8, which is < 0
    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.canDelete(transaction: buyTransaction) == false)
  }

  @Test("canDelete returns true when deleting the only buy transaction with no sells")
  func testCanDelete_OnlyBuyTransaction_NoSells_ReturnsTrue() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let buyTransaction = addTransaction(
      context: context, asset: asset, type: .buy, daysAgo: 5, quantity: 10)

    // Current quantity = 10, deleting buy(10) → quantity = 0, which is >= 0
    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)

    #expect(viewModel.canDelete(transaction: buyTransaction) == true)
  }

  // MARK: - Initiate Delete Tests

  @Test("Initiate delete when safe shows confirmation")
  func testInitiateDelete_Safe_ShowsConfirmation() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let transaction = addTransaction(
      context: context, asset: asset, type: .buy, daysAgo: 5, quantity: 10)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(transaction: transaction)

    #expect(viewModel.transactionToDelete?.id == transaction.id)
    #expect(viewModel.showingDeleteConfirmation == true)
    #expect(viewModel.deletionError == nil)
    #expect(viewModel.showingDeletionError == false)
  }

  @Test("Initiate delete when unsafe shows error")
  func testInitiateDelete_Unsafe_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let buyTransaction = addTransaction(
      context: context, asset: asset, type: .buy, daysAgo: 10, quantity: 10)
    addTransaction(context: context, asset: asset, type: .sell, daysAgo: 5, quantity: 8)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(transaction: buyTransaction)

    #expect(viewModel.transactionToDelete == nil)
    #expect(viewModel.showingDeleteConfirmation == false)
    #expect(viewModel.deletionError == .wouldCauseNegativeQuantity)
    #expect(viewModel.showingDeletionError == true)
  }

  // MARK: - Confirm Delete Tests

  @Test("Confirm delete removes transaction")
  func testConfirmDelete_RemovesTransaction() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let transaction = addTransaction(
      context: context, asset: asset, type: .buy, daysAgo: 5, quantity: 10)
    addTransaction(context: context, asset: asset, type: .buy, daysAgo: 1, quantity: 5)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(transaction: transaction)
    viewModel.confirmDelete()

    let fetchDescriptor = FetchDescriptor<Transaction>()
    let transactions = try context.fetch(fetchDescriptor)
    #expect(transactions.count == 1)
    #expect(transactions.first?.quantity == 5)
  }

  @Test("Confirm delete resets state")
  func testConfirmDelete_ResetsState() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let transaction = addTransaction(
      context: context, asset: asset, type: .buy, daysAgo: 5, quantity: 10)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(transaction: transaction)
    viewModel.confirmDelete()

    #expect(viewModel.transactionToDelete == nil)
    #expect(viewModel.showingDeleteConfirmation == false)
  }

  @Test("Confirm delete updates asset quantity")
  func testConfirmDelete_UpdatesAssetQuantity() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    addTransaction(context: context, asset: asset, type: .buy, daysAgo: 10, quantity: 10)
    let secondBuy = addTransaction(
      context: context, asset: asset, type: .buy, daysAgo: 5, quantity: 5)

    // Current quantity = 15
    #expect(asset.quantity == 15)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(transaction: secondBuy)
    viewModel.confirmDelete()

    try context.save()

    // After deleting buy(5), quantity should be 10
    #expect(asset.quantity == 10)
  }

  @Test("Confirm delete with nil transaction does nothing")
  func testConfirmDelete_NilTransaction_DoesNothing() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    addTransaction(context: context, asset: asset, type: .buy, daysAgo: 5, quantity: 10)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)
    // Don't initiate delete, so transactionToDelete is nil
    viewModel.confirmDelete()

    #expect(asset.transactions?.count == 1)
  }

  // MARK: - Cancel Delete Tests

  @Test("Cancel delete resets all state")
  func testCancelDelete_ResetsState() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let transaction = addTransaction(
      context: context, asset: asset, type: .buy, daysAgo: 5, quantity: 10)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(transaction: transaction)
    viewModel.cancelDelete()

    #expect(viewModel.transactionToDelete == nil)
    #expect(viewModel.showingDeleteConfirmation == false)
    #expect(viewModel.deletionError == nil)
    #expect(viewModel.showingDeletionError == false)
  }

  @Test("Cancel delete preserves transactions")
  func testCancelDelete_PreservesTransactions() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    let transaction = addTransaction(
      context: context, asset: asset, type: .buy, daysAgo: 5, quantity: 10)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)
    viewModel.initiateDelete(transaction: transaction)
    viewModel.cancelDelete()

    #expect(asset.transactions?.count == 1)
  }

  // MARK: - Field Preservation Tests

  @Test("Sorted transactions preserves all fields")
  func testSortedTransactions_PreservesAllFields() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    addTransaction(
      context: context, asset: asset, type: .buy, daysAgo: 5,
      quantity: 10, pricePerUnit: 150, totalAmount: 1500)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)
    let transaction = try #require(viewModel.sortedTransactions.first)

    #expect(transaction.transactionType == .buy)
    #expect(transaction.quantity == 10)
    #expect(transaction.pricePerUnit == 150)
    #expect(transaction.totalAmount == 1500)
    #expect(transaction.currency == "USD")
  }

  // MARK: - Multiple Types Tests

  @Test("Sorted transactions with multiple types ordered by date")
  func testSortedTransactions_MultipleTypes() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    addTransaction(context: context, asset: asset, type: .buy, daysAgo: 10, quantity: 10)
    addTransaction(context: context, asset: asset, type: .sell, daysAgo: 3, quantity: 5)
    addTransaction(context: context, asset: asset, type: .dividend, daysAgo: 1, quantity: 1)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)
    let sorted = viewModel.sortedTransactions

    #expect(sorted.count == 3)
    #expect(sorted[0].transactionType == .dividend)
    #expect(sorted[1].transactionType == .sell)
    #expect(sorted[2].transactionType == .buy)
  }

  // MARK: - Same Date Tests

  @Test("Sorted transactions with same date both present")
  func testSortedTransactions_SameDateTransactions() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)
    addTransaction(context: context, asset: asset, type: .buy, daysAgo: 1, quantity: 10)
    addTransaction(context: context, asset: asset, type: .sell, daysAgo: 1, quantity: 5)

    let viewModel = TransactionManagementViewModel(
      asset: asset, modelContext: context)
    let sorted = viewModel.sortedTransactions

    #expect(sorted.count == 2)
  }
}
