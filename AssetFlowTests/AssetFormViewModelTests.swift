//
//  AssetFormViewModelTests.swift
//  AssetFlowTests
//
//  Created by Claude on 2025/10/18.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("AssetFormViewModel Tests")
@MainActor
struct AssetFormViewModelTests {
  // MARK: - Initialization Tests

  @Test("ViewModel initializes correctly for a new asset")
  func testInitForNewAsset() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    // Act
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)

    // Assert
    #expect(viewModel.name.isEmpty)
    #expect(viewModel.assetType == .stock)  // Default value
    #expect(viewModel.quantity == "")
    #expect(viewModel.currentValue == "")
    #expect(viewModel.notes.isEmpty)
    #expect(viewModel.currency == "USD")  // Default currency
    #expect(viewModel.isEditing == false)
  }

  @Test("ViewModel initializes correctly for an existing asset")
  func testInitForExistingAsset() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let existingAsset = Asset(
      name: "Apple Inc.",
      assetType: .stock,
      currency: "USD",
      notes: "Tech stock",
      portfolio: portfolio
    )
    context.insert(existingAsset)

    // Add a transaction to set quantity
    let transaction = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 10,
      pricePerUnit: 150.0,
      totalAmount: 1500.0,
      asset: existingAsset
    )
    context.insert(transaction)

    // Add price history to set current value
    let priceHistory = PriceHistory(date: Date(), price: 175.0, asset: existingAsset)
    context.insert(priceHistory)

    // Act
    let viewModel = AssetFormViewModel(
      modelContext: context, portfolio: portfolio, asset: existingAsset)

    // Assert
    #expect(viewModel.name == "Apple Inc.")
    #expect(viewModel.assetType == .stock)
    #expect(viewModel.quantity == "10")
    #expect(viewModel.currentValue == "175")
    #expect(viewModel.notes == "Tech stock")
    #expect(viewModel.currency == "USD")
    #expect(viewModel.isEditing == true)
  }

  // MARK: - Name Validation Tests

  @Test("isSaveDisabled is true when name is empty")
  func testIsSaveDisabledTrueWhenNameEmpty() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)

    // Act
    viewModel.name = ""

    // Assert
    #expect(viewModel.isSaveDisabled == true)
    #expect(viewModel.nameValidationMessage == "Asset name cannot be empty.")
  }

  @Test("isSaveDisabled is true when name is only whitespace")
  func testIsSaveDisabledTrueWhenNameIsWhitespace() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)

    // Act
    viewModel.name = "   "

    // Assert
    #expect(viewModel.isSaveDisabled == true)
    #expect(viewModel.nameValidationMessage == "Asset name cannot be empty.")
  }

  @Test("isSaveDisabled is false when name is valid")
  func testIsSaveDisabledFalseWhenNameValid() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)

    // Act
    viewModel.name = "Apple Inc."
    viewModel.quantity = "10"
    viewModel.currentValue = "150"

    // Assert
    #expect(viewModel.isSaveDisabled == false)
    #expect(viewModel.nameValidationMessage == nil)
  }

  // MARK: - Quantity Validation Tests

  @Test("isSaveDisabled is true when quantity is empty")
  func testIsSaveDisabledTrueWhenQuantityEmpty() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Valid Name"

    // Act
    viewModel.quantity = ""

    // Assert
    #expect(viewModel.isSaveDisabled == true)
    #expect(viewModel.quantityValidationMessage == "Quantity is required.")
  }

  @Test("isSaveDisabled is true when quantity is not a valid number")
  func testIsSaveDisabledTrueWhenQuantityInvalid() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Valid Name"

    // Act
    viewModel.quantity = "abc"

    // Assert
    #expect(viewModel.isSaveDisabled == true)
    #expect(viewModel.quantityValidationMessage == "Quantity must be a valid number.")
  }

  @Test("isSaveDisabled is true when quantity is zero")
  func testIsSaveDisabledTrueWhenQuantityZero() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Valid Name"

    // Act
    viewModel.quantity = "0"

    // Assert
    #expect(viewModel.isSaveDisabled == true)
    #expect(viewModel.quantityValidationMessage == "Quantity must be greater than zero.")
  }

  @Test("isSaveDisabled is true when quantity is negative")
  func testIsSaveDisabledTrueWhenQuantityNegative() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Valid Name"

    // Act
    viewModel.quantity = "-5"

    // Assert
    #expect(viewModel.isSaveDisabled == true)
    #expect(viewModel.quantityValidationMessage == "Quantity must be greater than zero.")
  }

  @Test("isSaveDisabled is false when quantity is valid positive number")
  func testIsSaveDisabledFalseWhenQuantityValid() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Valid Name"
    viewModel.currentValue = "100.50"

    // Act
    viewModel.quantity = "10.5"

    // Assert
    #expect(viewModel.isSaveDisabled == false)
    #expect(viewModel.quantityValidationMessage == nil)
  }

  // MARK: - Current Value Validation Tests

  @Test("isSaveDisabled is true when current value is empty")
  func testIsSaveDisabledTrueWhenCurrentValueEmpty() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Valid Name"
    viewModel.quantity = "10"

    // Act
    viewModel.currentValue = ""

    // Assert
    #expect(viewModel.isSaveDisabled == true)
    #expect(viewModel.currentValueValidationMessage == "Current value is required.")
  }

  @Test("isSaveDisabled is true when current value is not a valid number")
  func testIsSaveDisabledTrueWhenCurrentValueInvalid() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Valid Name"
    viewModel.quantity = "10"

    // Act
    viewModel.currentValue = "xyz"

    // Assert
    #expect(viewModel.isSaveDisabled == true)
    #expect(viewModel.currentValueValidationMessage == "Current value must be a valid number.")
  }

  @Test("isSaveDisabled is true when current value is negative")
  func testIsSaveDisabledTrueWhenCurrentValueNegative() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Valid Name"
    viewModel.quantity = "10"

    // Act
    viewModel.currentValue = "-100"

    // Assert
    #expect(viewModel.isSaveDisabled == true)
    #expect(
      viewModel.currentValueValidationMessage == "Current value must be zero or greater.")
  }

  @Test("isSaveDisabled is false when current value is zero")
  func testIsSaveDisabledFalseWhenCurrentValueZero() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Valid Name"
    viewModel.quantity = "10"

    // Act
    viewModel.currentValue = "0"

    // Assert
    #expect(viewModel.isSaveDisabled == false)
    #expect(viewModel.currentValueValidationMessage == nil)
  }

  @Test("isSaveDisabled is false when current value is valid positive number")
  func testIsSaveDisabledFalseWhenCurrentValueValid() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)
    viewModel.name = "Valid Name"
    viewModel.quantity = "10"

    // Act
    viewModel.currentValue = "150.75"

    // Assert
    #expect(viewModel.isSaveDisabled == false)
    #expect(viewModel.currentValueValidationMessage == nil)
  }

  // MARK: - Save Tests

  @Test("save() creates a new asset with initial transaction and price history")
  func testSaveCreatesNewAsset() throws {
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
    viewModel.notes = "Tech stock"

    // Act
    viewModel.save()

    // Assert
    let fetchDescriptor = FetchDescriptor<Asset>()
    let assets = try context.fetch(fetchDescriptor)

    #expect(assets.count == 1)
    let asset = try #require(assets.first)
    #expect(asset.name == "Apple Inc.")
    #expect(asset.assetType == .stock)
    #expect(asset.currency == "USD")
    #expect(asset.notes == "Tech stock")
    #expect(asset.portfolio?.id == portfolio.id)

    // Verify transaction was created
    #expect(asset.transactions?.count == 1)
    let transaction = try #require(asset.transactions?.first)
    #expect(transaction.transactionType == .buy)
    #expect(transaction.quantity == 10)
    #expect(transaction.pricePerUnit == 150.50)

    // Verify price history was created
    #expect(asset.priceHistory?.count == 1)
    let priceHistory = try #require(asset.priceHistory?.first)
    #expect(priceHistory.price == 150.50)
  }

  @Test("save() updates an existing asset")
  func testSaveUpdatesExistingAsset() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let existingAsset = Asset(
      name: "Original Name",
      assetType: .stock,
      currency: "USD",
      notes: "Original notes",
      portfolio: portfolio
    )
    context.insert(existingAsset)

    // Add initial transaction
    let transaction = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 5,
      pricePerUnit: 100.0,
      totalAmount: 500.0,
      asset: existingAsset
    )
    context.insert(transaction)

    // Add initial price history
    let priceHistory = PriceHistory(date: Date(), price: 100.0, asset: existingAsset)
    context.insert(priceHistory)

    let viewModel = AssetFormViewModel(
      modelContext: context, portfolio: portfolio, asset: existingAsset)
    viewModel.name = "Updated Name"
    viewModel.assetType = .etf
    viewModel.notes = "Updated notes"
    // Note: For editing, quantity and currentValue are read-only (managed via transactions)

    // Act
    viewModel.save()

    // Assert
    let fetchDescriptor = FetchDescriptor<Asset>()
    let assets = try context.fetch(fetchDescriptor)

    #expect(assets.count == 1)
    let asset = try #require(assets.first)
    #expect(asset.name == "Updated Name")
    #expect(asset.assetType == .etf)
    #expect(asset.notes == "Updated notes")
    #expect(asset.id == existingAsset.id)
  }

  // MARK: - User Interaction Tests

  @Test("hasUserInteracted is set to true when name changes")
  func testUserInteractionFlagSetWhenNameChanges() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)
    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)

    // Act
    viewModel.name = "Apple Inc."

    // Assert
    #expect(viewModel.hasUserInteracted == true)
  }

  @Test("hasUserInteracted remains false when name is set to the same value")
  func testUserInteractionFlagNotSetWhenNameUnchanged() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let asset = Asset(name: "Apple Inc.", assetType: .stock, portfolio: portfolio)
    context.insert(asset)

    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio, asset: asset)

    // Act
    viewModel.name = "Apple Inc."  // Same as original

    // Assert
    #expect(viewModel.hasUserInteracted == false)
  }

  // MARK: - Asset Type/Currency Edit Restriction Tests

  @Test("canEditAssetType is true for new assets (no transactions or price history)")
  func testCanEditAssetTypeTrueForNewAsset() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)

    // Assert
    #expect(viewModel.canEditAssetType == true)
  }

  @Test("canEditAssetType is false when asset has transactions")
  func testCanEditAssetTypeFalseWhenHasTransactions() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let asset = Asset(name: "Apple Inc.", assetType: .stock, currency: "USD", portfolio: portfolio)
    context.insert(asset)

    let transaction = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 10,
      pricePerUnit: 150.0,
      totalAmount: 1500.0,
      asset: asset
    )
    context.insert(transaction)

    let viewModel = AssetFormViewModel(
      modelContext: context, portfolio: portfolio, asset: asset)

    // Assert
    #expect(viewModel.canEditAssetType == false)
  }

  @Test("canEditAssetType is false when asset has price history")
  func testCanEditAssetTypeFalseWhenHasPriceHistory() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let asset = Asset(name: "Apple Inc.", assetType: .stock, currency: "USD", portfolio: portfolio)
    context.insert(asset)

    let priceHistory = PriceHistory(date: Date(), price: 150.0, asset: asset)
    context.insert(priceHistory)

    let viewModel = AssetFormViewModel(
      modelContext: context, portfolio: portfolio, asset: asset)

    // Assert
    #expect(viewModel.canEditAssetType == false)
  }

  @Test("canEditCurrency is true for new assets")
  func testCanEditCurrencyTrueForNewAsset() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let viewModel = AssetFormViewModel(modelContext: context, portfolio: portfolio)

    // Assert
    #expect(viewModel.canEditCurrency == true)
  }

  @Test("canEditCurrency is false when asset has transactions")
  func testCanEditCurrencyFalseWhenHasTransactions() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let asset = Asset(name: "Apple Inc.", assetType: .stock, currency: "USD", portfolio: portfolio)
    context.insert(asset)

    let transaction = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: 10,
      pricePerUnit: 150.0,
      totalAmount: 1500.0,
      asset: asset
    )
    context.insert(transaction)

    let viewModel = AssetFormViewModel(
      modelContext: context, portfolio: portfolio, asset: asset)

    // Assert
    #expect(viewModel.canEditCurrency == false)
  }

  @Test("canEditCurrency is false when asset has price history")
  func testCanEditCurrencyFalseWhenHasPriceHistory() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    let asset = Asset(name: "Apple Inc.", assetType: .stock, currency: "USD", portfolio: portfolio)
    context.insert(asset)

    let priceHistory = PriceHistory(date: Date(), price: 150.0, asset: asset)
    context.insert(priceHistory)

    let viewModel = AssetFormViewModel(
      modelContext: context, portfolio: portfolio, asset: asset)

    // Assert
    #expect(viewModel.canEditCurrency == false)
  }
}
