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

  @Test("Portfolio deletion nullifies asset relationships")
  func deletePortfolio_NullifiesAssetRelationships() throws {
    // NOTE: Portfolio uses .nullify delete rule (not .deny) because SwiftData's
    // .deny rule has known bugs and doesn't work reliably as of 2024-2025.
    // Business logic MUST check portfolio.isEmpty before allowing deletion.

    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let portfolio = Portfolio(name: "Test Portfolio")
    let asset1 = Asset(name: "Asset 1", assetType: .cash, portfolio: portfolio)
    let asset2 = Asset(name: "Asset 2", assetType: .cash, portfolio: portfolio)

    context.insert(portfolio)
    context.insert(asset1)
    context.insert(asset2)
    try context.save()

    // Verify portfolio state - business logic should check this before deletion
    #expect(portfolio.assetCount == 2)
    #expect(!portfolio.isEmpty)

    // Act: Delete portfolio (business logic should prevent this, but testing the behavior)
    context.delete(portfolio)
    try context.save()

    // Assert: Assets remain but their portfolio reference is nullified
    let remainingAssets = try context.fetch(FetchDescriptor<Asset>())
    #expect(remainingAssets.count == 2, "Assets should not be deleted")
    #expect(
      remainingAssets.allSatisfy { $0.portfolio == nil },
      "Asset portfolio references should be nullified")
  }

  @Test("Deleting an empty Portfolio succeeds")
  func deletePortfolio_WithoutAssets_Succeeds() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let portfolio = Portfolio(name: "Empty Portfolio")
    context.insert(portfolio)
    try context.save()

    #expect(portfolio.isEmpty)
    #expect(portfolio.assetCount == 0)

    // Act
    context.delete(portfolio)
    try context.save()

    // Assert
    let remainingPortfolios = try context.fetch(FetchDescriptor<Portfolio>())
    #expect(remainingPortfolios.isEmpty, "Empty portfolio should be deleted successfully.")
  }

  @Test("Deleting an Asset cascades to delete its Transactions")
  func deleteAsset_CascadesDeleteToTransactions() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Asset", assetType: .stock)
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
    // The delete rule is .cascade, so transactions should be deleted when asset is deleted
    let finalTransactions = try context.fetch(FetchDescriptor<Transaction>())
    #expect(
      finalTransactions.isEmpty,
      "Transactions should be cascade-deleted when their asset is deleted.")
  }

  @Test("Deleting an Asset cascades to delete its PriceHistory")
  func deleteAsset_CascadesDeleteToPriceHistory() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let asset = Asset(name: "Test Asset", assetType: .stock)
    let price1 = PriceHistory(date: Date(), price: 100.0, asset: asset)
    let price2 = PriceHistory(date: Date().addingTimeInterval(-86400), price: 95.0, asset: asset)

    context.insert(asset)
    context.insert(price1)
    context.insert(price2)

    // Verify initial state
    #expect(price1.asset?.name == "Test Asset")
    #expect(price2.asset?.name == "Test Asset")

    // Act
    context.delete(asset)
    try context.save()

    // Assert
    // The delete rule is .cascade, so price history should be deleted when asset is deleted
    let finalPriceHistory = try context.fetch(FetchDescriptor<PriceHistory>())
    #expect(
      finalPriceHistory.isEmpty,
      "Price history should be cascade-deleted when their asset is deleted.")
  }
}
