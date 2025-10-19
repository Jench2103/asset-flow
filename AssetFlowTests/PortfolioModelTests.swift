//
//  PortfolioModelTests.swift
//  AssetFlowTests
//
//  Created by Gemini on 2025/10/12.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("Portfolio Model Tests")
@MainActor
struct PortfolioModelTests {

  @Test("totalValue is zero for new portfolio")
  func totalValue_IsZero_ForNewPortfolio() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio", portfolioDescription: "")
    context.insert(portfolio)

    // Mock exchange rates (1:1 for USD)
    let mockRates: [String: Decimal] = [:]

    // Act
    let totalValue = PortfolioValueCalculator.calculateTotalValue(
      for: portfolio.assets ?? [], using: mockRates, targetCurrency: "USD",
      ratesBaseCurrency: "USD")

    // Assert
    #expect(totalValue == 0)
  }

  @Test("totalValue sums the currentValue of its assets with currency conversion")
  func totalValue_SumsCurrentValueOfAssets() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let portfolio = Portfolio(name: "Test Portfolio", portfolioDescription: "")

    // Create assets with transactions and price history
    // Asset 1: 10 shares @ $125.05 = 1250.50 USD
    let asset1 = Asset(name: "Stock A", assetType: .stock, currency: "USD", portfolio: portfolio)
    let transaction1 = Transaction(
      transactionType: .buy, transactionDate: Date(), quantity: Decimal(10),
      pricePerUnit: Decimal(100), totalAmount: Decimal(1000), asset: asset1)
    let price1 = PriceHistory(date: Date(), price: Decimal(string: "125.05")!, asset: asset1)

    // Asset 2: 100 shares @ $30.0025 = 3000.25 USD
    let asset2 = Asset(name: "Stock B", assetType: .stock, currency: "USD", portfolio: portfolio)
    let transaction2 = Transaction(
      transactionType: .buy, transactionDate: Date(), quantity: Decimal(100),
      pricePerUnit: Decimal(25), totalAmount: Decimal(2500), asset: asset2)
    let price2 = PriceHistory(date: Date(), price: Decimal(string: "30.0025")!, asset: asset2)

    context.insert(portfolio)
    context.insert(asset1)
    context.insert(asset2)
    context.insert(transaction1)
    context.insert(transaction2)
    context.insert(price1)
    context.insert(price2)

    // Mock exchange rates (empty since all assets are in USD)
    let mockRates: [String: Decimal] = [:]

    // Act
    let totalValue = PortfolioValueCalculator.calculateTotalValue(
      for: portfolio.assets ?? [], using: mockRates, targetCurrency: "USD",
      ratesBaseCurrency: "USD")

    // Assert
    let expected = Decimal(string: "4250.75")!
    #expect(totalValue == expected)
  }

  // MARK: - Deletion Support Tests

  @Test("isEmpty returns true for portfolio with no assets")
  func isEmpty_NoAssets_ReturnsTrue() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Empty Portfolio")
    context.insert(portfolio)

    // Act & Assert
    #expect(portfolio.isEmpty == true)
    #expect(portfolio.assetCount == 0)
  }

  @Test("isEmpty returns false for portfolio with assets")
  func isEmpty_WithAssets_ReturnsFalse() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let portfolio = Portfolio(name: "Tech Portfolio")
    let asset = Asset(name: "Apple", assetType: .stock, currency: "USD", portfolio: portfolio)

    context.insert(portfolio)
    context.insert(asset)

    // Act & Assert
    #expect(portfolio.isEmpty == false)
    #expect(portfolio.assetCount == 1)
  }

  @Test("assetCount returns correct count for multiple assets")
  func assetCount_MultipleAssets_ReturnsCorrectCount() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let portfolio = Portfolio(name: "Diversified Portfolio")
    let asset1 = Asset(name: "Apple", assetType: .stock, portfolio: portfolio)
    let asset2 = Asset(name: "Microsoft", assetType: .stock, portfolio: portfolio)
    let asset3 = Asset(name: "Bitcoin", assetType: .crypto, portfolio: portfolio)

    context.insert(portfolio)
    context.insert(asset1)
    context.insert(asset2)
    context.insert(asset3)

    // Act & Assert
    #expect(portfolio.assetCount == 3)
    #expect(portfolio.isEmpty == false)
  }
}
