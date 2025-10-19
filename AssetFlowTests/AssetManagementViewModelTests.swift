//
//  AssetManagementViewModelTests.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/19.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("AssetManagementViewModel Tests")
@MainActor
struct AssetManagementViewModelTests {
  private var modelContext: ModelContext!
  private var container: ModelContainer!

  init() {
    do {
      let schema = Schema([
        Portfolio.self,
        Asset.self,
        Transaction.self,
        PriceHistory.self,
      ])
      let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
      container = try ModelContainer(for: schema, configurations: [configuration])
      modelContext = container.mainContext
    } catch {
      preconditionFailure("Failed to create model container: \(error)")
    }
  }

  // MARK: - Initialization Tests

  @Test("ViewModel initializes correctly")
  func testViewModelInitializes() {
    let viewModel = AssetManagementViewModel(modelContext: modelContext)

    #expect(viewModel.assetToDelete == nil)
    #expect(!viewModel.showingDeleteConfirmation)
    #expect(viewModel.deletionError == nil)
    #expect(!viewModel.showingDeletionError)
  }

  // MARK: - Initiate Delete Tests

  @Test("Initiate delete sets state correctly")
  func testInitiateDelete_ValidAsset_SetsState() {
    let portfolio = Portfolio(name: "Test Portfolio")
    modelContext.insert(portfolio)

    let asset = Asset(name: "Test Asset", assetType: .stock, currency: "USD", portfolio: portfolio)
    modelContext.insert(asset)

    let viewModel = AssetManagementViewModel(modelContext: modelContext)
    viewModel.initiateDelete(asset: asset)

    #expect(viewModel.assetToDelete == asset)
    #expect(viewModel.showingDeleteConfirmation)
    #expect(viewModel.deletionError == nil)
  }

  // MARK: - Confirm Delete Tests

  @Test("Confirm delete removes asset")
  func testConfirmDelete_ValidAsset_DeletesAsset() {
    let portfolio = Portfolio(name: "Test Portfolio")
    modelContext.insert(portfolio)

    let asset = Asset(name: "Test Asset", assetType: .stock, currency: "USD", portfolio: portfolio)
    modelContext.insert(asset)

    let viewModel = AssetManagementViewModel(modelContext: modelContext)
    viewModel.initiateDelete(asset: asset)
    viewModel.confirmDelete()

    // Asset should be deleted
    let fetchDescriptor = FetchDescriptor<Asset>(predicate: #Predicate { $0.name == "Test Asset" })
    let assets = try! modelContext.fetch(fetchDescriptor)
    #expect(assets.isEmpty)

    // State should be reset
    #expect(viewModel.assetToDelete == nil)
    #expect(!viewModel.showingDeleteConfirmation)
    #expect(viewModel.deletionError == nil)
  }

  @Test("Confirm delete cascades to transactions")
  func testConfirmDelete_WithTransactions_CascadesDelete() {
    let portfolio = Portfolio(name: "Test Portfolio")
    modelContext.insert(portfolio)

    let asset = Asset(name: "Test Asset", assetType: .stock, currency: "USD", portfolio: portfolio)
    modelContext.insert(asset)

    // Add transactions
    let transaction1 = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 10,
      pricePerUnit: 100,
      totalAmount: 1000,
      asset: asset
    )
    modelContext.insert(transaction1)

    let transaction2 = Transaction(
      transactionType: .sell,
      transactionDate: Date(),
      quantity: 5,
      pricePerUnit: 105,
      totalAmount: 525,
      asset: asset
    )
    modelContext.insert(transaction2)

    let viewModel = AssetManagementViewModel(modelContext: modelContext)
    viewModel.initiateDelete(asset: asset)
    viewModel.confirmDelete()

    // Transactions should be deleted (cascade)
    let transactionFetchDescriptor = FetchDescriptor<Transaction>()
    let transactions = try! modelContext.fetch(transactionFetchDescriptor)
    #expect(transactions.isEmpty)
  }

  @Test("Confirm delete cascades to price history")
  func testConfirmDelete_WithPriceHistory_CascadesDelete() {
    let portfolio = Portfolio(name: "Test Portfolio")
    modelContext.insert(portfolio)

    let asset = Asset(name: "Test Asset", assetType: .stock, currency: "USD", portfolio: portfolio)
    modelContext.insert(asset)

    // Add price history
    let priceHistory1 = PriceHistory(date: Date(), price: 100, asset: asset)
    modelContext.insert(priceHistory1)

    let priceHistory2 = PriceHistory(
      date: Date().addingTimeInterval(-86400), price: 99, asset: asset)
    modelContext.insert(priceHistory2)

    let viewModel = AssetManagementViewModel(modelContext: modelContext)
    viewModel.initiateDelete(asset: asset)
    viewModel.confirmDelete()

    // Price history should be deleted (cascade)
    let priceHistoryFetchDescriptor = FetchDescriptor<PriceHistory>()
    let priceHistories = try! modelContext.fetch(priceHistoryFetchDescriptor)
    #expect(priceHistories.isEmpty)
  }

  @Test("Confirm delete with no asset does nothing")
  func testConfirmDelete_NoAssetSet_DoesNothing() {
    let viewModel = AssetManagementViewModel(modelContext: modelContext)
    viewModel.confirmDelete()

    #expect(viewModel.assetToDelete == nil)
    #expect(!viewModel.showingDeleteConfirmation)
  }

  // MARK: - Cancel Delete Tests

  @Test("Cancel delete resets state without deleting")
  func testCancelDelete_ResetsState() {
    let portfolio = Portfolio(name: "Test Portfolio")
    modelContext.insert(portfolio)

    let asset = Asset(name: "Test Asset", assetType: .stock, currency: "USD", portfolio: portfolio)
    modelContext.insert(asset)

    let viewModel = AssetManagementViewModel(modelContext: modelContext)
    viewModel.initiateDelete(asset: asset)

    #expect(viewModel.showingDeleteConfirmation)

    viewModel.cancelDelete()

    #expect(viewModel.assetToDelete == nil)
    #expect(!viewModel.showingDeleteConfirmation)
    #expect(viewModel.deletionError == nil)

    // Asset should still exist
    let fetchDescriptor = FetchDescriptor<Asset>(predicate: #Predicate { $0.name == "Test Asset" })
    let assets = try! modelContext.fetch(fetchDescriptor)
    #expect(assets.count == 1)
  }

  // MARK: - Multiple Assets Tests

  @Test("Confirm delete only removes target asset, not others")
  func testConfirmDelete_OnlyTargetAssetDeleted() {
    let portfolio = Portfolio(name: "Test Portfolio")
    modelContext.insert(portfolio)

    let asset1 = Asset(name: "Asset 1", assetType: .stock, currency: "USD", portfolio: portfolio)
    modelContext.insert(asset1)

    let asset2 = Asset(name: "Asset 2", assetType: .crypto, currency: "USD", portfolio: portfolio)
    modelContext.insert(asset2)

    let viewModel = AssetManagementViewModel(modelContext: modelContext)
    viewModel.initiateDelete(asset: asset1)
    viewModel.confirmDelete()

    // Asset 1 should be deleted
    let asset1FetchDescriptor = FetchDescriptor<Asset>(
      predicate: #Predicate { $0.name == "Asset 1" })
    let deletedAssets = try! modelContext.fetch(asset1FetchDescriptor)
    #expect(deletedAssets.isEmpty)

    // Asset 2 should still exist
    let asset2FetchDescriptor = FetchDescriptor<Asset>(
      predicate: #Predicate { $0.name == "Asset 2" })
    let remainingAssets = try! modelContext.fetch(asset2FetchDescriptor)
    #expect(remainingAssets.count == 1)
  }
}
