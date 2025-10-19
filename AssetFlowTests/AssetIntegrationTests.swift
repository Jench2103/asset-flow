//
//  AssetIntegrationTests.swift
//  AssetFlowTests
//
//  Created by Claude on 2025/10/18.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("Asset Integration Tests")
@MainActor
struct AssetIntegrationTests {
  // MARK: - Asset Creation Integration Tests

  @Test("Asset is successfully saved to SwiftData with initial transaction")
  func testAssetSavedWithInitialTransaction() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Apple Inc."
    viewModel.assetType = .stock
    viewModel.quantity = "10"
    viewModel.currentValue = "150.50"
    viewModel.currency = "USD"

    // Act
    viewModel.save()

    // Assert - Verify asset exists
    let assetFetch = FetchDescriptor<Asset>()
    let assets = try context.fetch(assetFetch)
    #expect(assets.count == 1)

    let asset = try #require(assets.first)
    #expect(asset.name == "Apple Inc.")
    #expect(asset.assetType == .stock)

    // Verify transaction was created
    let transactionFetch = FetchDescriptor<Transaction>()
    let transactions = try context.fetch(transactionFetch)
    #expect(transactions.count == 1)

    let transaction = try #require(transactions.first)
    #expect(transaction.transactionType == .buy)
    #expect(transaction.quantity == 10)
    #expect(transaction.asset?.id == asset.id)
  }

  @Test("Asset is correctly associated with its parent portfolio")
  func testAssetAssociatedWithPortfolio() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Tech Portfolio")
    context.insert(portfolio)

    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Microsoft Corp."
    viewModel.assetType = .stock
    viewModel.quantity = "5"
    viewModel.currentValue = "350.00"

    // Act
    viewModel.save()

    // Assert - Check asset's portfolio relationship
    let assetFetch = FetchDescriptor<Asset>()
    let assets = try context.fetch(assetFetch)
    let asset = try #require(assets.first)
    #expect(asset.portfolio?.id == portfolio.id)

    // Check portfolio's assets relationship
    #expect(portfolio.assets?.count == 1)
    #expect(portfolio.assets?.first?.id == asset.id)
  }

  @Test("Multiple assets can be added to the same portfolio")
  func testMultipleAssetsInPortfolio() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Diversified Portfolio")
    context.insert(portfolio)

    // Act - Add first asset
    let viewModel1 = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel1.name = "Apple Inc."
    viewModel1.assetType = .stock
    viewModel1.quantity = "10"
    viewModel1.currentValue = "150.00"
    viewModel1.save()

    // Add second asset
    let viewModel2 = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel2.name = "Bitcoin"
    viewModel2.assetType = .crypto
    viewModel2.quantity = "0.5"
    viewModel2.currentValue = "45000.00"
    viewModel2.save()

    // Assert
    let assetFetch = FetchDescriptor<Asset>()
    let assets = try context.fetch(assetFetch)
    #expect(assets.count == 2)
    #expect(portfolio.assets?.count == 2)

    let assetNames = assets.map { $0.name }.sorted()
    #expect(assetNames == ["Apple Inc.", "Bitcoin"])
  }

  @Test("Asset price history is created when asset is saved")
  func testAssetPriceHistoryCreated() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Tesla"
    viewModel.assetType = .stock
    viewModel.quantity = "20"
    viewModel.currentValue = "250.75"

    // Act
    viewModel.save()

    // Assert
    let priceHistoryFetch = FetchDescriptor<PriceHistory>()
    let priceHistories = try context.fetch(priceHistoryFetch)
    #expect(priceHistories.count == 1)

    let priceHistory = try #require(priceHistories.first)
    #expect(priceHistory.price == 250.75)

    // Verify it's linked to the asset
    let assetFetch = FetchDescriptor<Asset>()
    let assets = try context.fetch(assetFetch)
    let asset = try #require(assets.first)
    #expect(priceHistory.asset?.id == asset.id)
    #expect(asset.priceHistory?.count == 1)
  }

  // MARK: - Asset Editing Integration Tests

  @Test("Editing an asset updates its properties")
  func testEditingAssetUpdatesProperties() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let asset = Asset(
      name: "Original Name",
      assetType: .stock,
      currency: "USD",
      notes: "Original notes",
      portfolio: portfolio
    )
    context.insert(asset)

    // Add initial transaction
    let transaction = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 10,
      pricePerUnit: 100.0,
      totalAmount: 1000.0,
      asset: asset
    )
    context.insert(transaction)

    // Add price history
    let priceHistory = PriceHistory(date: Date(), price: 100.0, asset: asset)
    context.insert(priceHistory)

    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio, asset: asset)

    // Act
    viewModel.name = "Updated Name"
    viewModel.assetType = .etf
    viewModel.notes = "Updated notes"
    viewModel.save()

    // Assert
    let assetFetch = FetchDescriptor<Asset>()
    let assets = try context.fetch(assetFetch)
    #expect(assets.count == 1)

    let updatedAsset = try #require(assets.first)
    #expect(updatedAsset.id == asset.id)
    #expect(updatedAsset.name == "Updated Name")
    #expect(updatedAsset.assetType == .etf)
    #expect(updatedAsset.notes == "Updated notes")

    // Verify transaction count hasn't changed (editing doesn't add new transactions)
    let transactionFetch = FetchDescriptor<Transaction>()
    let transactions = try context.fetch(transactionFetch)
    #expect(transactions.count == 1)
  }

  @Test("Portfolio's total value reflects new asset")
  func testPortfolioTotalValueUpdatesWithNewAsset() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    // Mock exchange rates (empty since all assets are in USD)
    let mockRates: [String: Decimal] = [:]

    // Initial total value should be 0
    #expect(
      PortfolioValueCalculator.calculateTotalValue(
        for: portfolio.assets ?? [], using: mockRates, targetCurrency: "USD",
        ratesBaseCurrency: "USD")
        == 0)

    // Act - Add asset
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Apple Inc."
    viewModel.assetType = .stock
    viewModel.currency = "USD"
    viewModel.quantity = "10"
    viewModel.currentValue = "150.50"
    viewModel.save()

    // Assert
    // Total value should be 10 * 150.50 = 1505.00
    #expect(
      PortfolioValueCalculator.calculateTotalValue(
        for: portfolio.assets ?? [], using: mockRates, targetCurrency: "USD",
        ratesBaseCurrency: "USD")
        == 1505.00)
  }

  @Test("Portfolio's asset count increases when asset is added")
  func testPortfolioAssetCountIncreasesWithNewAsset() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    #expect(portfolio.assetCount == 0)

    // Act - Add first asset
    let viewModel1 = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel1.name = "Asset 1"
    viewModel1.assetType = .stock
    viewModel1.quantity = "5"
    viewModel1.currentValue = "100.00"
    viewModel1.save()

    #expect(portfolio.assetCount == 1)

    // Add second asset
    let viewModel2 = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel2.name = "Asset 2"
    viewModel2.assetType = .bond
    viewModel2.quantity = "10"
    viewModel2.currentValue = "50.00"
    viewModel2.save()

    // Assert
    #expect(portfolio.assetCount == 2)
  }

  @Test("Asset quantity is correctly calculated from transaction")
  func testAssetQuantityFromTransaction() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Test Asset"
    viewModel.assetType = .stock
    viewModel.quantity = "15.5"
    viewModel.currentValue = "200.00"
    viewModel.save()

    // Assert
    let assetFetch = FetchDescriptor<Asset>()
    let assets = try context.fetch(assetFetch)
    let asset = try #require(assets.first)

    // The quantity should match what we set
    #expect(asset.quantity == 15.5)
  }

  @Test("Asset current value is correctly calculated")
  func testAssetCurrentValueCalculation() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Test Asset"
    viewModel.assetType = .stock
    viewModel.quantity = "10"
    viewModel.currentValue = "125.50"
    viewModel.save()

    // Assert
    let assetFetch = FetchDescriptor<Asset>()
    let assets = try context.fetch(assetFetch)
    let asset = try #require(assets.first)

    // Current value = quantity * current price = 10 * 125.50 = 1255.00
    #expect(asset.currentValue == 1255.00)
  }
}
