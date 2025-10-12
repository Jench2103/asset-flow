//
//  SwiftDataRelationshipTests.swift
//  AssetFlowTests
//
//  Created by Gemini on 2025/10/12.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("SwiftData Relationship Tests")
@MainActor
struct SwiftDataRelationshipTests {

  @Test("Deleting a Portfolio nullifies the relationship on its Assets")
  func deletePortfolio_NullifiesRelationshipOnAssets() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let portfolio = Portfolio(name: "Test Portfolio")
    let asset1 = Asset(
      name: "Asset 1", assetType: .cash, currentValue: 100, purchaseDate: Date(),
      portfolio: portfolio)
    let asset2 = Asset(
      name: "Asset 2", assetType: .cash, currentValue: 200, purchaseDate: Date(),
      portfolio: portfolio)

    context.insert(portfolio)
    context.insert(asset1)
    context.insert(asset2)

    // Verify initial state
    #expect(asset1.portfolio?.name == "Test Portfolio")
    #expect(asset2.portfolio?.name == "Test Portfolio")

    // Act
    context.delete(portfolio)
    try context.save()

    // Assert
    // The default delete rule is .nullify, so the assets should still exist but their link to the portfolio should be nil.
    let finalAssets = try context.fetch(FetchDescriptor<Asset>())
    #expect(finalAssets.count == 2, "Assets should not be deleted.")
    #expect(
      finalAssets.allSatisfy { $0.portfolio == nil },
      "The portfolio property on the assets should be nullified.")
  }

  @Test("Deleting an Asset nullifies the relationship on its Transactions")
  func deleteAsset_NullifiesRelationshipOnTransactions() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(
      name: "Test Asset", assetType: .stock, currentValue: 1000, purchaseDate: Date())
    let transaction1 = Transaction(
      transactionType: .buy, transactionDate: Date(), quantity: 10, pricePerUnit: 50,
      totalAmount: 500, asset: asset)
    let transaction2 = Transaction(
      transactionType: .sell, transactionDate: Date(), quantity: 5, pricePerUnit: 60,
      totalAmount: 300, asset: asset)

    context.insert(asset)
    context.insert(transaction1)
    context.insert(transaction2)

    // Verify initial state
    #expect(transaction1.asset?.name == "Test Asset")
    #expect(transaction2.asset?.name == "Test Asset")

    // Act
    context.delete(asset)
    try context.save()

    // Assert
    // The default delete rule is .nullify, so the transactions should still exist but their link to the asset should be nil.
    let finalTransactions = try context.fetch(FetchDescriptor<Transaction>())
    #expect(finalTransactions.count == 2, "Transactions should not be deleted.")
    #expect(
      finalTransactions.allSatisfy { $0.asset == nil },
      "The asset property on the transactions should be nullified.")
  }
}
