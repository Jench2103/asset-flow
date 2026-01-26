//
//  PriceHistoryFormViewModelTests.swift
//  AssetFlowTests
//
//  Created by Claude on 2025/10/20.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("PriceHistoryFormViewModel Tests")
@MainActor
struct PriceHistoryFormViewModelTests {

  // MARK: - Helper

  private func createAssetWithPriceHistory(
    context: ModelContext, date: Date = Date(), price: Decimal = 100.0
  ) -> (Asset, PriceHistory) {
    let asset = Asset(name: "Test Asset", assetType: .stock, currency: "USD")
    context.insert(asset)
    let record = PriceHistory(date: date, price: price, asset: asset)
    context.insert(record)
    return (asset, record)
  }

  // MARK: - Initialization Tests

  @Test("Init for new record sets default values")
  func testInitForNewRecord() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(context: context)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)

    #expect(viewModel.isEditing == false)
    #expect(viewModel.priceText == "")
    #expect(viewModel.navigationTitle == "Add Price Record")
    // Date defaults to today
    #expect(Calendar.current.isDateInToday(viewModel.date))
  }

  @Test("Init for existing record populates form fields")
  func testInitForExistingRecord() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let recordDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
    let (asset, record) = createAssetWithPriceHistory(
      context: context, date: recordDate, price: 150.75)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset, priceHistory: record)

    #expect(viewModel.isEditing == true)
    #expect(viewModel.priceText == "150.75")
    #expect(Calendar.current.isDate(viewModel.date, inSameDayAs: recordDate))
    #expect(viewModel.navigationTitle == "Edit Price Record")
  }

  // MARK: - Date Validation Tests

  @Test("Date validation: today is valid")
  func testDateValidation_Today_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(
      context: context,
      date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.date = Date()

    #expect(viewModel.dateValidationMessage == nil)
  }

  @Test("Date validation: past date is valid")
  func testDateValidation_PastDate_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(
      context: context,
      date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.date = Calendar.current.date(byAdding: .day, value: -5, to: Date())!

    #expect(viewModel.dateValidationMessage == nil)
  }

  @Test("Date validation: future date shows error")
  func testDateValidation_FutureDate_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(context: context)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.date = Calendar.current.date(byAdding: .day, value: 5, to: Date())!

    #expect(viewModel.dateValidationMessage != nil)
    #expect(viewModel.dateValidationMessage == "Date cannot be in the future.")
  }

  @Test("Date validation: duplicate date shows error")
  func testDateValidation_DuplicateDate_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let existingDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
    let (asset, _) = createAssetWithPriceHistory(
      context: context, date: existingDate)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.date = existingDate

    #expect(viewModel.dateValidationMessage != nil)
    #expect(
      viewModel.dateValidationMessage
        == "A price record already exists for this date.")
  }

  @Test("Date validation: editing same date is valid")
  func testDateValidation_EditingSameDate_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let existingDate = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
    let (asset, record) = createAssetWithPriceHistory(
      context: context, date: existingDate)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset, priceHistory: record)
    // Keep the same date — should be valid
    viewModel.date = existingDate

    #expect(viewModel.dateValidationMessage == nil)
  }

  @Test("Date validation: editing to different existing date shows error")
  func testDateValidation_EditingDifferentExistingDate_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let date1 = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
    let date2 = Calendar.current.date(byAdding: .day, value: -3, to: Date())!

    let asset = Asset(name: "Test Asset", assetType: .stock, currency: "USD")
    context.insert(asset)
    let record1 = PriceHistory(date: date1, price: 100.0, asset: asset)
    let record2 = PriceHistory(date: date2, price: 110.0, asset: asset)
    context.insert(record1)
    context.insert(record2)

    // Editing record1, trying to change its date to date2
    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset, priceHistory: record1)
    viewModel.date = date2

    #expect(viewModel.dateValidationMessage != nil)
    #expect(
      viewModel.dateValidationMessage
        == "A price record already exists for this date.")
  }

  @Test("Date validation: unique date among multiple records is valid")
  func testDateValidation_UniqueDateAmongMultipleRecords_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let date1 = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
    let date2 = Calendar.current.date(byAdding: .day, value: -5, to: Date())!

    let asset = Asset(name: "Test Asset", assetType: .stock, currency: "USD")
    context.insert(asset)
    context.insert(PriceHistory(date: date1, price: 100.0, asset: asset))
    context.insert(PriceHistory(date: date2, price: 110.0, asset: asset))

    // Adding a new record on a date that doesn't conflict
    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.date = Calendar.current.date(byAdding: .day, value: -3, to: Date())!

    #expect(viewModel.dateValidationMessage == nil)
  }

  @Test("Date validation: editing record to unused date is valid")
  func testDateValidation_EditingToUnusedDate_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let date1 = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
    let date2 = Calendar.current.date(byAdding: .day, value: -5, to: Date())!

    let asset = Asset(name: "Test Asset", assetType: .stock, currency: "USD")
    context.insert(asset)
    let record1 = PriceHistory(date: date1, price: 100.0, asset: asset)
    context.insert(record1)
    context.insert(PriceHistory(date: date2, price: 110.0, asset: asset))

    // Editing record1 to a date that doesn't conflict with record2
    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset, priceHistory: record1)
    viewModel.date = Calendar.current.date(byAdding: .day, value: -3, to: Date())!

    #expect(viewModel.dateValidationMessage == nil)
  }

  // MARK: - Price Validation Tests

  @Test("Price validation: empty shows error")
  func testPriceValidation_Empty_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(context: context)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.priceText = ""

    #expect(viewModel.priceValidationMessage == "Price is required.")
  }

  @Test("Price validation: invalid number shows error")
  func testPriceValidation_InvalidNumber_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(context: context)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.priceText = "abc"

    #expect(viewModel.priceValidationMessage == "Price must be a valid number.")
  }

  @Test("Price validation: negative shows error")
  func testPriceValidation_Negative_ShowsError() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(context: context)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.priceText = "-5"

    #expect(viewModel.priceValidationMessage == "Price must be zero or greater.")
  }

  @Test("Price validation: zero is valid")
  func testPriceValidation_Zero_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(context: context)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.priceText = "0"

    #expect(viewModel.priceValidationMessage == nil)
  }

  @Test("Price validation: valid positive is valid")
  func testPriceValidation_ValidPositive_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(context: context)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.priceText = "175.50"

    #expect(viewModel.priceValidationMessage == nil)
  }

  @Test("Price validation: valid decimal is valid")
  func testPriceValidation_ValidDecimal_IsValid() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(context: context)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.priceText = "0.001"

    #expect(viewModel.priceValidationMessage == nil)
  }

  // MARK: - Combined Validation Tests

  @Test("Combined validation: both invalid means save disabled")
  func testCombinedValidation_BothInvalid_SaveDisabled() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(context: context)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.date = Calendar.current.date(byAdding: .day, value: 5, to: Date())!
    viewModel.priceText = ""

    #expect(viewModel.isSaveDisabled == true)
  }

  @Test("Combined validation: both valid means save enabled")
  func testCombinedValidation_BothValid_SaveEnabled() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(
      context: context,
      date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    viewModel.priceText = "100.00"

    #expect(viewModel.isSaveDisabled == false)
  }

  // MARK: - Save (Add) Tests

  @Test("Save new record creates PriceHistory")
  func testSave_NewRecord_CreatesPriceHistory() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(
      context: context,
      date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    viewModel.priceText = "200.00"
    viewModel.save()

    #expect(asset.priceHistory?.count == 2)
  }

  @Test("Save new latest record updates current price")
  func testSave_NewLatestRecord_UpdatesCurrentPrice() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(
      context: context,
      date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!,
      price: 100.0)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.date = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
    viewModel.priceText = "200.00"
    viewModel.save()

    #expect(asset.currentPrice == 200.0)
  }

  @Test("Save new older record does not change current price")
  func testSave_NewOlderRecord_DoesNotChangeCurrentPrice() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(
      context: context,
      date: Calendar.current.date(byAdding: .day, value: -1, to: Date())!,
      price: 200.0)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    viewModel.date = Calendar.current.date(byAdding: .day, value: -10, to: Date())!
    viewModel.priceText = "50.00"
    viewModel.save()

    #expect(asset.currentPrice == 200.0)
  }

  // MARK: - Save (Edit) Tests

  @Test("Save edit updates existing record")
  func testSave_EditRecord_UpdatesExistingRecord() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let existingDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
    let (asset, record) = createAssetWithPriceHistory(
      context: context, date: existingDate, price: 100.0)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset, priceHistory: record)
    viewModel.priceText = "250.00"
    viewModel.save()

    #expect(record.price == 250.0)
  }

  @Test("Save edit does not create new record")
  func testSave_EditRecord_DoesNotCreateNewRecord() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let existingDate = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
    let (asset, record) = createAssetWithPriceHistory(
      context: context, date: existingDate, price: 100.0)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset, priceHistory: record)
    viewModel.priceText = "250.00"
    viewModel.save()

    #expect(asset.priceHistory?.count == 1)
  }

  // MARK: - User Interaction Tests

  @Test("Price change sets interaction flag")
  func testUserInteraction_PriceChange_SetsFlag() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(context: context)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    #expect(viewModel.hasPriceInteraction == false)

    viewModel.priceText = "100"

    #expect(viewModel.hasPriceInteraction == true)
  }

  @Test("Date change sets interaction flag")
  func testUserInteraction_DateChange_SetsFlag() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let (asset, _) = createAssetWithPriceHistory(
      context: context,
      date: Calendar.current.date(byAdding: .day, value: -10, to: Date())!)

    let viewModel = PriceHistoryFormViewModel(
      modelContext: context, asset: asset)
    #expect(viewModel.hasDateInteraction == false)

    viewModel.date = Calendar.current.date(byAdding: .day, value: -5, to: Date())!

    #expect(viewModel.hasDateInteraction == true)
  }
}
