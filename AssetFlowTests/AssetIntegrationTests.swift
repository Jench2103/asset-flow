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
    viewModel.costBasis = "150.50"
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
    viewModel.costBasis = "350.00"

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
    viewModel1.costBasis = "150.00"
    viewModel1.save()

    // Add second asset
    let viewModel2 = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel2.name = "Bitcoin"
    viewModel2.assetType = .crypto
    viewModel2.quantity = "0.5"
    viewModel2.costBasis = "45000.00"
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
    viewModel.costBasis = "250.75"

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
    viewModel.costBasis = "150.50"
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
    viewModel1.costBasis = "100.00"
    viewModel1.save()

    #expect(portfolio.assetCount == 1)

    // Add second asset
    let viewModel2 = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel2.name = "Asset 2"
    viewModel2.assetType = .bond
    viewModel2.quantity = "10"
    viewModel2.costBasis = "50.00"
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
    viewModel.costBasis = "200.00"
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
    viewModel.costBasis = "125.50"
    viewModel.save()

    // Assert
    let assetFetch = FetchDescriptor<Asset>()
    let assets = try context.fetch(assetFetch)
    let asset = try #require(assets.first)

    // Current value = quantity * current price = 10 * 125.50 = 1255.00
    #expect(asset.currentValue == 1255.00)
  }

  // MARK: - Current Price Date Tests

  @Test("currentPriceDate returns nil when no price history exists")
  func testCurrentPriceDate_NoPriceHistory_ReturnsNil() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Asset", assetType: .stock)
    context.insert(asset)

    // Assert
    #expect(asset.currentPriceDate == nil)
  }

  @Test("currentPriceDate returns date when single price record exists")
  func testCurrentPriceDate_SingleRecord_ReturnsDate() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Asset", assetType: .stock)
    context.insert(asset)

    let recordDate = Date()
    let priceHistory = PriceHistory(date: recordDate, price: 100.0, asset: asset)
    context.insert(priceHistory)

    // Assert
    #expect(asset.currentPriceDate != nil)
    #expect(
      Calendar.current.isDate(asset.currentPriceDate!, inSameDayAs: recordDate))
  }

  @Test("currentPriceDate returns most recent date when multiple records exist")
  func testCurrentPriceDate_MultipleRecords_ReturnsMostRecentDate() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Asset", assetType: .stock)
    context.insert(asset)

    let oldDate = Calendar.current.date(byAdding: .day, value: -30, to: Date())!
    let recentDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

    let oldRecord = PriceHistory(date: oldDate, price: 90.0, asset: asset)
    let recentRecord = PriceHistory(date: recentDate, price: 110.0, asset: asset)
    context.insert(oldRecord)
    context.insert(recentRecord)

    // Assert
    #expect(asset.currentPriceDate != nil)
    #expect(
      Calendar.current.isDate(asset.currentPriceDate!, inSameDayAs: recentDate))
  }

  // MARK: - Average Cost Basis Tests

  @Test("Average cost for single buy transaction")
  func testAverageCost_SingleBuy() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Stock", assetType: .stock)
    context.insert(asset)

    let transaction = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 10,
      pricePerUnit: 100,
      totalAmount: 1000,
      asset: asset
    )
    context.insert(transaction)

    // Assert
    #expect(asset.averageCost == 100)
    #expect(asset.costBasis == 1000)
  }

  @Test("Average cost for multiple buy transactions at different prices")
  func testAverageCost_MultipleBuys() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Stock", assetType: .stock)
    context.insert(asset)

    let buy1 = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 10,
      pricePerUnit: 100,
      totalAmount: 1000,
      asset: asset
    )
    context.insert(buy1)

    let buy2 = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 5,
      pricePerUnit: 200,
      totalAmount: 1000,
      asset: asset
    )
    context.insert(buy2)

    // Assert
    // Average cost = 2000 / 15 ≈ 133.33...
    let expectedAvgCost: Decimal = 2000 / 15
    #expect(asset.averageCost == expectedAvgCost)
  }

  @Test("Average cost ignores non-buy transactions")
  func testAverageCost_NonBuyTransactionsIgnored() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Stock", assetType: .stock)
    context.insert(asset)

    let buy = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 10,
      pricePerUnit: 100,
      totalAmount: 1000,
      asset: asset
    )
    context.insert(buy)

    let sell = Transaction(
      transactionType: .sell,
      transactionDate: Date(),
      quantity: 3,
      pricePerUnit: 120,
      totalAmount: 360,
      asset: asset
    )
    context.insert(sell)

    let dividend = Transaction(
      transactionType: .dividend,
      transactionDate: Date(),
      quantity: 0,
      pricePerUnit: 0,
      totalAmount: 50,
      asset: asset
    )
    context.insert(dividend)

    // Assert - average cost only reflects the buy
    #expect(asset.averageCost == 100)
  }

  @Test("Average cost is zero when no buy transactions exist")
  func testAverageCost_NoBuyTransactions() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Stock", assetType: .stock)
    context.insert(asset)

    // Assert
    #expect(asset.averageCost == 0)
    #expect(asset.costBasis == 0)
  }

  // MARK: - Unrealized Gain/Loss Tests

  @Test("Unrealized gain when current price exceeds cost basis")
  func testUnrealizedGainLoss_GainScenario() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Stock", assetType: .stock)
    context.insert(asset)

    // Buy 10 @ $100 (cost basis = $1000)
    let buy = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 10,
      pricePerUnit: 100,
      totalAmount: 1000,
      asset: asset
    )
    context.insert(buy)

    // Current price = $150 (current value = $1500)
    let priceHistory = PriceHistory(date: Date(), price: 150, asset: asset)
    context.insert(priceHistory)

    // Assert
    #expect(asset.unrealizedGainLoss == 500)
    #expect(asset.unrealizedGainLossPercentage == 50)
  }

  @Test("Unrealized loss when current price is below cost basis")
  func testUnrealizedGainLoss_LossScenario() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Stock", assetType: .stock)
    context.insert(asset)

    // Buy 10 @ $100 (cost basis = $1000)
    let buy = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 10,
      pricePerUnit: 100,
      totalAmount: 1000,
      asset: asset
    )
    context.insert(buy)

    // Current price = $80 (current value = $800)
    let priceHistory = PriceHistory(date: Date(), price: 80, asset: asset)
    context.insert(priceHistory)

    // Assert
    #expect(asset.unrealizedGainLoss == -200)
    #expect(asset.unrealizedGainLossPercentage == -20)
  }

  @Test("Unrealized gain/loss is zero at break-even")
  func testUnrealizedGainLoss_BreakEven() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Stock", assetType: .stock)
    context.insert(asset)

    // Buy 10 @ $100 (cost basis = $1000)
    let buy = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 10,
      pricePerUnit: 100,
      totalAmount: 1000,
      asset: asset
    )
    context.insert(buy)

    // Current price = $100 (current value = $1000)
    let priceHistory = PriceHistory(date: Date(), price: 100, asset: asset)
    context.insert(priceHistory)

    // Assert
    #expect(asset.unrealizedGainLoss == 0)
    #expect(asset.unrealizedGainLossPercentage == 0)
  }

  @Test("Unrealized gain/loss is zero when cost basis is zero")
  func testUnrealizedGainLoss_ZeroCostBasis() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Stock", assetType: .stock)
    context.insert(asset)

    // No buy transactions, but has a current price
    let priceHistory = PriceHistory(date: Date(), price: 150, asset: asset)
    context.insert(priceHistory)

    // Assert
    #expect(asset.unrealizedGainLoss == 0)
    #expect(asset.unrealizedGainLossPercentage == 0)
  }
}
