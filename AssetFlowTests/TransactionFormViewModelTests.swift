//
//  TransactionFormViewModelTests.swift
//  AssetFlowTests
//
//  Created by Claude on 2026/1/26.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("TransactionFormViewModel Tests", .serialized)
@MainActor
struct TransactionFormViewModelTests {

  // MARK: - Helpers

  private func createAsset(
    context: ModelContext,
    assetType: AssetType = .stock,
    currency: String = "USD"
  ) -> Asset {
    let asset = Asset(name: "Test Asset", assetType: assetType, currency: currency)
    context.insert(asset)
    return asset
  }

  private func createAssetWithPrice(
    context: ModelContext,
    assetType: AssetType = .stock,
    price: Decimal = 150
  ) -> Asset {
    let asset = createAsset(context: context, assetType: assetType)
    let priceRecord = PriceHistory(date: Date(), price: price, asset: asset)
    context.insert(priceRecord)
    return asset
  }

  private func createAssetWithHoldings(
    context: ModelContext,
    quantity: Decimal = 10,
    pricePerUnit: Decimal = 100
  ) -> Asset {
    let asset = createAssetWithPrice(context: context, price: pricePerUnit)
    let transaction = Transaction(
      transactionType: .buy,
      transactionDate: Date(),
      quantity: quantity,
      pricePerUnit: pricePerUnit,
      totalAmount: quantity * pricePerUnit,
      currency: "USD",
      asset: asset
    )
    context.insert(transaction)
    return asset
  }

  // MARK: - Initialization Tests

  @Test("Init sets default values with price pre-filled")
  func testInit_DefaultValues() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAssetWithPrice(context: context, price: 150)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)

    #expect(viewModel.transactionType == .buy)
    #expect(Calendar.current.isDateInToday(viewModel.transactionDate))
    #expect(viewModel.quantityText == "")
    #expect(viewModel.pricePerUnitText == "150")
  }

  @Test("Init with no price history sets empty price")
  func testInit_NoPriceHistory_EmptyPrice() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)

    #expect(viewModel.pricePerUnitText == "")
  }

  // MARK: - Date Validation Tests

  @Test("Date validation: today is valid")
  func testDateValidation_Today_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.transactionDate = Date()

    #expect(viewModel.dateValidationMessage == nil)
  }

  @Test("Date validation: past date is valid")
  func testDateValidation_PastDate_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.transactionDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!

    #expect(viewModel.dateValidationMessage == nil)
  }

  @Test("Date validation: future date shows error")
  func testDateValidation_FutureDate_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.transactionDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!

    #expect(viewModel.dateValidationMessage == "Date cannot be in the future.")
  }

  // MARK: - Quantity Validation Tests

  @Test("Quantity validation: empty shows error")
  func testQuantityValidation_Empty_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.quantityText = ""

    #expect(viewModel.quantityValidationMessage == "Quantity is required.")
  }

  @Test("Quantity validation: invalid number shows error")
  func testQuantityValidation_InvalidNumber_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.quantityText = "abc"

    #expect(viewModel.quantityValidationMessage == "Quantity must be a valid number.")
  }

  @Test("Quantity validation: zero shows error")
  func testQuantityValidation_Zero_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.quantityText = "0"

    #expect(viewModel.quantityValidationMessage == "Quantity must be greater than zero.")
  }

  @Test("Quantity validation: negative shows error")
  func testQuantityValidation_Negative_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.quantityText = "-5"

    #expect(viewModel.quantityValidationMessage == "Quantity must be greater than zero.")
  }

  @Test("Quantity validation: valid positive is valid")
  func testQuantityValidation_ValidPositive_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.quantityText = "10"

    #expect(viewModel.quantityValidationMessage == nil)
  }

  // MARK: - Price Per Unit Validation Tests

  @Test("Price per unit validation: empty shows error")
  func testPricePerUnitValidation_Empty_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.pricePerUnitText = ""

    #expect(viewModel.pricePerUnitValidationMessage == "Price per unit is required.")
  }

  @Test("Price per unit validation: invalid number shows error")
  func testPricePerUnitValidation_InvalidNumber_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.pricePerUnitText = "abc"

    #expect(viewModel.pricePerUnitValidationMessage == "Price per unit must be a valid number.")
  }

  @Test("Price per unit validation: negative shows error")
  func testPricePerUnitValidation_Negative_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.pricePerUnitText = "-5"

    #expect(viewModel.pricePerUnitValidationMessage == "Price per unit must be zero or greater.")
  }

  @Test("Price per unit validation: zero is valid")
  func testPricePerUnitValidation_Zero_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.pricePerUnitText = "0"

    #expect(viewModel.pricePerUnitValidationMessage == nil)
  }

  @Test("Price per unit validation: valid positive is valid")
  func testPricePerUnitValidation_ValidPositive_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.pricePerUnitText = "150.50"

    #expect(viewModel.pricePerUnitValidationMessage == nil)
  }

  // MARK: - Combined Validation Tests

  @Test("Combined: all invalid means save disabled")
  func testCombinedValidation_AllInvalid_SaveDisabled() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.transactionDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
    viewModel.quantityText = ""
    viewModel.pricePerUnitText = ""

    #expect(viewModel.isSaveDisabled == true)
  }

  @Test("Combined: all valid means save enabled")
  func testCombinedValidation_AllValid_SaveEnabled() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.transactionDate = Date()
    viewModel.quantityText = "10"
    viewModel.pricePerUnitText = "100"

    #expect(viewModel.isSaveDisabled == false)
  }

  // MARK: - Calculated Total Amount Tests

  @Test("Calculated total amount: valid inputs returns quantity * pricePerUnit")
  func testCalculatedTotalAmount_ValidInputs() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.quantityText = "10"
    viewModel.pricePerUnitText = "150"

    #expect(viewModel.calculatedTotalAmount == 1500)
  }

  @Test("Calculated total amount: invalid inputs returns nil")
  func testCalculatedTotalAmount_InvalidInputs_ReturnsNil() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.quantityText = "abc"
    viewModel.pricePerUnitText = "100"

    #expect(viewModel.calculatedTotalAmount == nil)
  }

  // MARK: - Save Tests

  @Test("Save creates transaction linked to asset with correct fields")
  func testSave_CreatesTransaction() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.transactionType = .buy
    viewModel.quantityText = "10"
    viewModel.pricePerUnitText = "150"
    viewModel.save()

    let transactions = asset.transactions ?? []
    #expect(transactions.count == 1)

    let transaction = try #require(transactions.first)
    #expect(transaction.transactionType == .buy)
    #expect(transaction.quantity == 10)
    #expect(transaction.pricePerUnit == 150)
    #expect(transaction.totalAmount == 1500)
    #expect(transaction.currency == "USD")
    #expect(transaction.asset?.id == asset.id)
  }

  @Test("Save buy transaction increases asset quantity")
  func testSave_BuyTransaction_IncreasesQuantity() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.transactionType = .buy
    viewModel.quantityText = "10"
    viewModel.pricePerUnitText = "100"
    viewModel.save()

    #expect(asset.quantity == 10)
  }

  @Test("Save sell transaction decreases asset quantity")
  func testSave_SellTransaction_DecreasesQuantity() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAssetWithHoldings(context: context, quantity: 10, pricePerUnit: 100)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.transactionType = .sell
    viewModel.quantityText = "3"
    viewModel.pricePerUnitText = "110"
    viewModel.save()

    #expect(asset.quantity == 7)
  }

  // MARK: - Sell Validation Tests

  @Test("Sell validation: quantity exceeding holdings shows error")
  func testSellValidation_ExceedingHoldings_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAssetWithHoldings(context: context, quantity: 10, pricePerUnit: 100)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.transactionType = .sell
    viewModel.quantityText = "15"

    #expect(viewModel.quantityValidationMessage != nil)
    #expect(
      viewModel.quantityValidationMessage!.contains("Cannot sell more than current holdings"))
  }

  @Test("Sell validation: quantity within holdings is valid")
  func testSellValidation_WithinHoldings_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAssetWithHoldings(context: context, quantity: 10, pricePerUnit: 100)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.transactionType = .sell
    viewModel.quantityText = "5"

    #expect(viewModel.quantityValidationMessage == nil)
  }

  @Test("TransferOut validation: same as sell prevents overselling")
  func testTransferOutValidation_ExceedingHoldings_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAssetWithHoldings(context: context, quantity: 10, pricePerUnit: 100)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    viewModel.transactionType = .transferOut
    viewModel.quantityText = "15"

    #expect(viewModel.quantityValidationMessage != nil)
    #expect(
      viewModel.quantityValidationMessage!.contains(
        "Cannot transfer out more than current holdings"
      ))
  }

  // MARK: - Display Name Tests

  @Test("Display name for cash asset: buy shows Deposit")
  func testDisplayName_CashAsset_Buy_ShowsDeposit() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context, assetType: .cash)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)

    #expect(viewModel.displayName(for: .buy) == "Deposit")
  }

  @Test("Display name for cash asset: sell shows Withdrawal")
  func testDisplayName_CashAsset_Sell_ShowsWithdrawal() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context, assetType: .cash)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)

    #expect(viewModel.displayName(for: .sell) == "Withdrawal")
  }

  @Test("Display name for non-cash asset: buy shows Buy")
  func testDisplayName_NonCashAsset_Buy_ShowsBuy() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context, assetType: .stock)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)

    #expect(viewModel.displayName(for: .buy) == "Buy")
  }

  @Test("Display name for non-cash asset: sell shows Sell")
  func testDisplayName_NonCashAsset_Sell_ShowsSell() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context, assetType: .stock)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)

    #expect(viewModel.displayName(for: .sell) == "Sell")
  }

  // MARK: - Interaction Flag Tests

  @Test("Date change sets interaction flag")
  func testDateChange_SetsInteractionFlag() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    #expect(viewModel.hasDateInteraction == false)

    viewModel.transactionDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())!

    #expect(viewModel.hasDateInteraction == true)
  }

  @Test("Quantity change sets interaction flag")
  func testQuantityChange_SetsInteractionFlag() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    #expect(viewModel.hasQuantityInteraction == false)

    viewModel.quantityText = "10"

    #expect(viewModel.hasQuantityInteraction == true)
  }

  @Test("Price per unit change sets interaction flag")
  func testPricePerUnitChange_SetsInteractionFlag() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let asset = createAsset(context: context)

    let viewModel = TransactionFormViewModel(modelContext: context, asset: asset)
    #expect(viewModel.hasPricePerUnitInteraction == false)

    viewModel.pricePerUnitText = "100"

    #expect(viewModel.hasPricePerUnitInteraction == true)
  }
}
