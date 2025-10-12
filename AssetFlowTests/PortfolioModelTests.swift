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

    // Create assets with specific stored currentValue, matching the actual Asset model
    let asset1 = Asset(
      name: "Stock A", assetType: .stock, currentValue: 1250.50, purchaseDate: Date())
    let asset2 = Asset(
      name: "Stock B", assetType: .stock, currentValue: 3000.25, purchaseDate: Date())

    portfolio.assets = [asset1, asset2]
    context.insert(portfolio)
    context.insert(asset1)
    context.insert(asset2)

    // Act
    let totalValue = portfolio.totalValue  // Should be 1250.50 + 3000.25 = 4250.75

    // Assert
    #expect(totalValue == 4250.75)
  }
}
