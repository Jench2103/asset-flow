//
//  PortfolioDetailViewModelTests.swift
//  AssetFlowTests
//
//  Created by Claude on 2025/10/18.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("PortfolioDetailViewModel Tests")
@MainActor
struct PortfolioDetailViewModelTests {

  // MARK: - Initialization Tests

  @Test("ViewModel initializes with correct portfolio reference")
  func viewModelInitializesWithPortfolio() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    // Act
    let viewModel = PortfolioDetailViewModel(portfolio: portfolio, modelContext: context)

    // Assert
    #expect(viewModel.portfolio.id == portfolio.id)
    #expect(viewModel.modelContext === context)
  }

  // MARK: - Total Value Calculation Tests

  @Test("Total value is zero for empty portfolio")
  func totalValueIsZeroForEmptyPortfolio() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Empty Portfolio")
    context.insert(portfolio)

    // Act
    let viewModel = PortfolioDetailViewModel(portfolio: portfolio, modelContext: context)

    // Assert
    #expect(viewModel.totalValue == 0)
  }

  @Test("Total value is calculated correctly with single asset")
  func totalValueCalculatedCorrectlyWithSingleAsset() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Tech Portfolio")
    context.insert(portfolio)

    let asset = Asset(name: "Apple", assetType: .stock, portfolio: portfolio)
    context.insert(asset)

    // Add price history and transaction to set up value
    let priceHistory = PriceHistory(date: Date(), price: 150.0, asset: asset)
    context.insert(priceHistory)

    let transaction = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 10,
      pricePerUnit: 100.0,
      totalAmount: 1000.0,
      currency: "USD",
      asset: asset
    )
    context.insert(transaction)

    // Act
    let viewModel = PortfolioDetailViewModel(portfolio: portfolio, modelContext: context)

    // Assert
    // Current value = quantity (10) * current price (150) = 1500
    #expect(viewModel.totalValue == 1500)
  }

  @Test("Total value aggregates multiple assets correctly")
  func totalValueAggregatesMultipleAssets() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Diversified Portfolio")
    context.insert(portfolio)

    // Asset 1: Apple - 10 shares @ $150 = $1,500
    let apple = Asset(name: "Apple", assetType: .stock, portfolio: portfolio)
    context.insert(apple)
    context.insert(PriceHistory(date: Date(), price: 150.0, asset: apple))
    context.insert(
      Transaction(
        transactionType: .buy, transactionDate: Date(), quantity: 10,
        pricePerUnit: 100.0, totalAmount: 1000.0, currency: "USD", asset: apple))

    // Asset 2: Bitcoin - 0.5 BTC @ $40,000 = $20,000
    let bitcoin = Asset(name: "Bitcoin", assetType: .crypto, portfolio: portfolio)
    context.insert(bitcoin)
    context.insert(PriceHistory(date: Date(), price: 40000.0, asset: bitcoin))
    context.insert(
      Transaction(
        transactionType: .buy, transactionDate: Date(), quantity: 0.5,
        pricePerUnit: 35000.0, totalAmount: 17500.0, currency: "USD", asset: bitcoin))

    // Asset 3: Bonds - 100 units @ $50 = $5,000
    let bonds = Asset(name: "Treasury Bonds", assetType: .bond, portfolio: portfolio)
    context.insert(bonds)
    context.insert(PriceHistory(date: Date(), price: 50.0, asset: bonds))
    context.insert(
      Transaction(
        transactionType: .buy, transactionDate: Date(), quantity: 100,
        pricePerUnit: 48.0, totalAmount: 4800.0, currency: "USD", asset: bonds))

    // Act
    let viewModel = PortfolioDetailViewModel(portfolio: portfolio, modelContext: context)

    // Assert
    // Total = 1,500 + 20,000 + 5,000 = 26,500
    #expect(viewModel.totalValue == 26500)
  }

  // MARK: - Asset Count Tests

  @Test("Asset count is zero for empty portfolio")
  func assetCountIsZeroForEmptyPortfolio() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Empty Portfolio")
    context.insert(portfolio)

    // Act
    let viewModel = PortfolioDetailViewModel(portfolio: portfolio, modelContext: context)

    // Assert
    #expect(viewModel.assetCount == 0)
  }

  @Test("Asset count matches number of assets in portfolio")
  func assetCountMatchesNumberOfAssets() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    // Add 3 assets
    let asset1 = Asset(name: "Asset 1", assetType: .stock, portfolio: portfolio)
    let asset2 = Asset(name: "Asset 2", assetType: .bond, portfolio: portfolio)
    let asset3 = Asset(name: "Asset 3", assetType: .crypto, portfolio: portfolio)
    context.insert(asset1)
    context.insert(asset2)
    context.insert(asset3)

    // Act
    let viewModel = PortfolioDetailViewModel(portfolio: portfolio, modelContext: context)

    // Assert
    #expect(viewModel.assetCount == 3)
  }

  // MARK: - Assets List Tests

  @Test("Assets list is empty for portfolio with no assets")
  func assetsListIsEmptyForPortfolioWithNoAssets() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Empty Portfolio")
    context.insert(portfolio)

    // Act
    let viewModel = PortfolioDetailViewModel(portfolio: portfolio, modelContext: context)

    // Assert
    #expect(viewModel.assets.isEmpty)
  }

  @Test("Assets list contains all portfolio assets")
  func assetsListContainsAllPortfolioAssets() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let asset1 = Asset(name: "Apple", assetType: .stock, portfolio: portfolio)
    let asset2 = Asset(name: "Bitcoin", assetType: .crypto, portfolio: portfolio)
    let asset3 = Asset(name: "Gold", assetType: .commodity, portfolio: portfolio)
    context.insert(asset1)
    context.insert(asset2)
    context.insert(asset3)

    // Act
    let viewModel = PortfolioDetailViewModel(portfolio: portfolio, modelContext: context)

    // Assert
    #expect(viewModel.assets.count == 3)
    #expect(viewModel.assets.contains(where: { $0.name == "Apple" }))
    #expect(viewModel.assets.contains(where: { $0.name == "Bitcoin" }))
    #expect(viewModel.assets.contains(where: { $0.name == "Gold" }))
  }
}
