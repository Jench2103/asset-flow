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

    // Act
    let totalValue = portfolio.totalValue

    // Assert
    #expect(totalValue == 0)
  }

  @Test("totalValue sums the currentValue of its assets")
  func totalValue_SumsCurrentValueOfAssets() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let portfolio = Portfolio(name: "Test Portfolio", portfolioDescription: "")

    // Create assets with transactions and price history
    // Asset 1: 10 shares @ $125.05 = 1250.50
    let asset1 = Asset(name: "Stock A", assetType: .stock, portfolio: portfolio)
    let transaction1 = Transaction(
      transactionType: .buy, transactionDate: Date(), quantity: Decimal(10),
      pricePerUnit: Decimal(100), totalAmount: Decimal(1000), asset: asset1)
    let price1 = PriceHistory(date: Date(), price: Decimal(string: "125.05")!, asset: asset1)

    // Asset 2: 100 shares @ $30.0025 = 3000.25
    let asset2 = Asset(name: "Stock B", assetType: .stock, portfolio: portfolio)
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

    // Act
    let totalValue = portfolio.totalValue  // Should be 1250.50 + 3000.25 = 4250.75

    // Assert
    let expected = Decimal(string: "4250.75")!
    #expect(totalValue == expected)
  }
}
