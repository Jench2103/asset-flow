//
//  TransactionHistoryViewModelTests.swift
//  AssetFlowTests
//
//  Created by Claude on 2026/1/26.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("TransactionHistoryViewModel Tests", .serialized)
@MainActor
struct TransactionHistoryViewModelTests {

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

    let viewModel = TransactionHistoryViewModel(asset: asset)
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

    let viewModel = TransactionHistoryViewModel(asset: asset)

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

    let viewModel = TransactionHistoryViewModel(asset: asset)

    #expect(viewModel.transactionCount == 3)
  }

  @Test("Transaction count with no transactions returns zero")
  func testTransactionCount_NoTransactions_ReturnsZero() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionHistoryViewModel(asset: asset)

    #expect(viewModel.transactionCount == 0)
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

    let viewModel = TransactionHistoryViewModel(asset: asset)
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

    let viewModel = TransactionHistoryViewModel(asset: asset)
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

    let viewModel = TransactionHistoryViewModel(asset: asset)
    let sorted = viewModel.sortedTransactions

    #expect(sorted.count == 2)
  }
}
