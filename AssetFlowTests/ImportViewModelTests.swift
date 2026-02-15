//
//  ImportViewModelTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("ImportViewModel Tests")
@MainActor
struct ImportViewModelTests {

  // MARK: - Test Helpers

  private struct TestContext {
    let container: ModelContainer
    let context: ModelContext
  }

  private func createTestContext() -> TestContext {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    return TestContext(container: container, context: context)
  }

  private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar.current.date(from: components)!
  }

  private func csvData(_ string: String) -> Data {
    string.data(using: .utf8)!
  }

  private func validAssetCSVData() -> Data {
    csvData(
      """
      Asset Name,Market Value,Platform
      AAPL,15000,Interactive Brokers
      VTI,28000,Interactive Brokers
      Bitcoin,5000,Coinbase
      """)
  }

  private func validCashFlowCSVData() -> Data {
    csvData(
      """
      Description,Amount
      Salary deposit,50000
      Emergency fund transfer,-10000
      """)
  }

  // MARK: - Import Type Selection

  @Test("Default import type is assets")
  func defaultImportTypeIsAssets() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    #expect(viewModel.importType == .assets)
  }

  @Test("Switching import type clears loaded file and preview data")
  func switchingImportTypeClearsData() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    // Load an asset CSV
    viewModel.loadCSVData(validAssetCSVData())
    #expect(!viewModel.assetPreviewRows.isEmpty)

    // Switch to cash flows
    viewModel.importType = .cashFlows

    #expect(viewModel.assetPreviewRows.isEmpty)
    #expect(viewModel.cashFlowPreviewRows.isEmpty)
    #expect(viewModel.validationErrors.isEmpty)
    #expect(viewModel.validationWarnings.isEmpty)
    #expect(viewModel.selectedFileURL == nil)
  }

  // MARK: - File Loading: Asset CSV

  @Test("Loading valid asset CSV populates preview rows")
  func loadValidAssetCSV() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.loadCSVData(validAssetCSVData())

    #expect(viewModel.assetPreviewRows.count == 3)
    #expect(viewModel.assetPreviewRows[0].csvRow.assetName == "AAPL")
    #expect(viewModel.assetPreviewRows[0].csvRow.marketValue == Decimal(15000))
    #expect(viewModel.assetPreviewRows[0].csvRow.platform == "Interactive Brokers")
    #expect(viewModel.assetPreviewRows[0].isIncluded)
    #expect(viewModel.validationErrors.isEmpty)
  }

  @Test("Loading asset CSV with errors populates validation errors")
  func loadAssetCSVWithErrors() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    let csv = csvData(
      """
      Asset Name,Market Value
      ,15000
      AAPL,abc
      """)
    viewModel.loadCSVData(csv)

    #expect(!viewModel.validationErrors.isEmpty)
  }

  @Test("Loading asset CSV with warnings populates validation warnings")
  func loadAssetCSVWithWarnings() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    let csv = csvData(
      """
      Asset Name,Market Value
      AAPL,0
      VTI,-100
      """)
    viewModel.loadCSVData(csv)

    #expect(!viewModel.validationWarnings.isEmpty)
  }

  @Test("Loading empty file shows error")
  func loadEmptyFile() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.loadCSVData(csvData(""))

    #expect(!viewModel.validationErrors.isEmpty)
    #expect(viewModel.assetPreviewRows.isEmpty)
  }

  @Test("Loading headers-only file shows no data rows error")
  func loadHeadersOnlyFile() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.loadCSVData(csvData("Asset Name,Market Value\n"))

    #expect(!viewModel.validationErrors.isEmpty)
  }

  // MARK: - File Loading: Cash Flow CSV

  @Test("Loading valid cash flow CSV populates preview rows")
  func loadValidCashFlowCSV() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.importType = .cashFlows

    viewModel.loadCSVData(validCashFlowCSVData())

    #expect(viewModel.cashFlowPreviewRows.count == 2)
    #expect(viewModel.cashFlowPreviewRows[0].csvRow.description == "Salary deposit")
    #expect(viewModel.cashFlowPreviewRows[0].csvRow.amount == Decimal(50000))
    #expect(viewModel.cashFlowPreviewRows[0].isIncluded)
    #expect(viewModel.validationErrors.isEmpty)
  }

  @Test("Loading cash flow CSV with errors populates validation errors")
  func loadCashFlowCSVWithErrors() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.importType = .cashFlows

    let csv = csvData(
      """
      Description,Amount
      ,50000
      Salary,abc
      """)
    viewModel.loadCSVData(csv)

    #expect(!viewModel.validationErrors.isEmpty)
  }

  // MARK: - Snapshot Date Validation

  @Test("Default snapshot date is today")
  func defaultSnapshotDateIsToday() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    let today = Calendar.current.startOfDay(for: Date())
    let vmDate = Calendar.current.startOfDay(for: viewModel.snapshotDate)
    #expect(vmDate == today)
  }

  @Test("Future date produces validation error on import")
  func futureDateProducesError() throws {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    // Set a future date
    let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    viewModel.snapshotDate = futureDate

    viewModel.loadCSVData(validAssetCSVData())

    // Import should fail with future date error
    let result = viewModel.executeImport()
    #expect(result == nil)
    #expect(viewModel.importError != nil)
  }

  @Test("Past date is valid for import")
  func pastDateIsValid() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validAssetCSVData())

    #expect(viewModel.isImportDisabled == false)
  }

  // MARK: - Platform Handling

  @Test("Import-level platform overrides CSV platform values in preview")
  func importPlatformOverridesCSV() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.selectedPlatform = "Schwab"
    viewModel.loadCSVData(validAssetCSVData())

    // All rows should have the import-level platform
    for row in viewModel.assetPreviewRows {
      #expect(row.csvRow.platform == "Schwab")
    }
  }

  @Test("No import-level platform uses CSV per-row platforms")
  func noImportPlatformUsesCSVValues() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.loadCSVData(validAssetCSVData())

    #expect(viewModel.assetPreviewRows[0].csvRow.platform == "Interactive Brokers")
    #expect(viewModel.assetPreviewRows[2].csvRow.platform == "Coinbase")
  }

  @Test("New platform name is used as platform string")
  func newPlatformNameUsed() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.selectedPlatform = "My New Broker"
    viewModel.loadCSVData(validAssetCSVData())

    for row in viewModel.assetPreviewRows {
      #expect(row.csvRow.platform == "My New Broker")
    }
  }

  // MARK: - Category Handling

  @Test("Import-level category is recorded for import execution")
  func importCategoryRecorded() throws {
    let tc = createTestContext()
    let category = Category(name: "Equities", targetAllocationPercentage: 60)
    tc.context.insert(category)

    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.selectedCategory = category
    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validAssetCSVData())

    let snapshot = viewModel.executeImport()
    #expect(snapshot != nil)

    // All created assets should have the selected category
    let assetDescriptor = FetchDescriptor<Asset>()
    let assets = try tc.context.fetch(assetDescriptor)
    for asset in assets {
      #expect(asset.category?.id == category.id)
    }
  }

  @Test("New category with existing name reuses existing category")
  func newCategoryReusesExisting() {
    let tc = createTestContext()
    let existing = Category(name: "Equities", targetAllocationPercentage: 60)
    tc.context.insert(existing)

    let viewModel = ImportViewModel(modelContext: tc.context)
    let resolved = viewModel.resolveCategory(name: "equities")

    #expect(resolved?.id == existing.id)
  }

  @Test("New category with genuinely new name creates category with nil target")
  func newCategoryCreatesNew() throws {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)
    let resolved = viewModel.resolveCategory(name: "Crypto")

    #expect(resolved != nil)
    #expect(resolved?.name == "Crypto")
    #expect(resolved?.targetAllocationPercentage == nil)

    let catDescriptor = FetchDescriptor<AssetFlow.Category>()
    let allCategories = try tc.context.fetch(catDescriptor)
    #expect(allCategories.count == 1)
  }

  @Test("Category reassignment warning when asset has different existing category")
  func categoryReassignmentWarning() {
    let tc = createTestContext()

    // Create an existing asset with category "Bonds"
    let bonds = Category(name: "Bonds")
    tc.context.insert(bonds)
    let asset = Asset(name: "AAPL", platform: "Interactive Brokers")
    asset.category = bonds
    tc.context.insert(asset)

    // Import with different category
    let equities = Category(name: "Equities")
    tc.context.insert(equities)

    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.selectedCategory = equities
    viewModel.loadCSVData(validAssetCSVData())

    // The AAPL row should have a category warning
    let aaplRow = viewModel.assetPreviewRows.first {
      $0.csvRow.assetName == "AAPL"
    }
    #expect(aaplRow?.categoryWarning != nil)
  }

  // MARK: - Row Removal

  @Test("Removing a row from preview excludes it from import")
  func removeRowExcludesFromImport() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.loadCSVData(validAssetCSVData())
    #expect(viewModel.assetPreviewRows.count == 3)

    viewModel.removeAssetPreviewRow(at: 0)

    let included = viewModel.assetPreviewRows.filter { $0.isIncluded }
    #expect(included.count == 2)
  }

  @Test("Removing all rows disables import")
  func removeAllRowsDisablesImport() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.loadCSVData(validAssetCSVData())

    for i in 0..<viewModel.assetPreviewRows.count {
      viewModel.removeAssetPreviewRow(at: i)
    }

    #expect(viewModel.isImportDisabled)
  }

  @Test("Removing row that was part of duplicate pair clears duplicate error")
  func removeRowClearsDuplicateError() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    // CSV with duplicate assets
    let csv = csvData(
      """
      Asset Name,Market Value
      AAPL,15000
      AAPL,20000
      """)
    viewModel.loadCSVData(csv)

    #expect(!viewModel.validationErrors.isEmpty)

    // Remove the duplicate row
    viewModel.removeAssetPreviewRow(at: 1)

    // After removing the duplicate, errors should be re-evaluated
    #expect(viewModel.validationErrors.isEmpty)
  }

  // MARK: - Duplicate Detection (CSV vs Existing Snapshot)

  @Test("Duplicate asset between CSV and existing snapshot produces error")
  func duplicateAssetWithExistingSnapshot() {
    let tc = createTestContext()

    // Create existing snapshot with AAPL
    let date = makeDate(year: 2025, month: 6, day: 15)
    let snapshot = Snapshot(date: date)
    tc.context.insert(snapshot)
    let asset = Asset(name: "AAPL", platform: "Interactive Brokers")
    tc.context.insert(asset)
    let sav = SnapshotAssetValue(marketValue: 10000)
    sav.snapshot = snapshot
    sav.asset = asset
    tc.context.insert(sav)

    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.snapshotDate = date
    viewModel.loadCSVData(validAssetCSVData())

    // Should detect duplicate AAPL on Interactive Brokers
    let hasDuplicateError = viewModel.validationErrors.contains {
      $0.message.contains("AAPL")
    }
    #expect(hasDuplicateError)
  }

  @Test("Duplicate cash flow between CSV and existing snapshot produces error")
  func duplicateCashFlowWithExistingSnapshot() {
    let tc = createTestContext()

    // Create existing snapshot with a cash flow
    let date = makeDate(year: 2025, month: 6, day: 15)
    let snapshot = Snapshot(date: date)
    tc.context.insert(snapshot)
    let cf = CashFlowOperation(cashFlowDescription: "Salary deposit", amount: 50000)
    cf.snapshot = snapshot
    tc.context.insert(cf)

    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.importType = .cashFlows
    viewModel.snapshotDate = date
    viewModel.loadCSVData(validCashFlowCSVData())

    let hasDuplicateError = viewModel.validationErrors.contains {
      $0.message.lowercased().contains("salary deposit")
    }
    #expect(hasDuplicateError)
  }

  @Test("No duplicates when snapshot is new")
  func noDuplicatesForNewSnapshot() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validAssetCSVData())

    #expect(viewModel.validationErrors.isEmpty)
  }

  @Test("Excluded rows do not participate in duplicate detection with snapshot")
  func excludedRowsSkipDuplicateDetection() {
    let tc = createTestContext()

    // Create existing snapshot with AAPL
    let date = makeDate(year: 2025, month: 6, day: 15)
    let snapshot = Snapshot(date: date)
    tc.context.insert(snapshot)
    let asset = Asset(name: "AAPL", platform: "Interactive Brokers")
    tc.context.insert(asset)
    let sav = SnapshotAssetValue(marketValue: 10000)
    sav.snapshot = snapshot
    sav.asset = asset
    tc.context.insert(sav)

    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.snapshotDate = date

    let csv = csvData(
      """
      Asset Name,Market Value,Platform
      AAPL,15000,Interactive Brokers
      VTI,28000,Interactive Brokers
      """)
    viewModel.loadCSVData(csv)

    // Initially there should be a duplicate error for AAPL
    #expect(!viewModel.validationErrors.isEmpty)

    // Remove the AAPL row
    viewModel.removeAssetPreviewRow(at: 0)

    // Duplicate error should be cleared
    #expect(viewModel.validationErrors.isEmpty)
  }

  // MARK: - Import Execution: Asset CSV

  @Test("Importing creates new snapshot if none exists for date")
  func importCreatesNewSnapshot() throws {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    let date = makeDate(year: 2025, month: 6, day: 15)
    viewModel.snapshotDate = date
    viewModel.loadCSVData(validAssetCSVData())

    let snapshot = viewModel.executeImport()

    #expect(snapshot != nil)
    #expect(snapshot?.date == Calendar.current.startOfDay(for: date))

    let snapshotDescriptor = FetchDescriptor<Snapshot>()
    let allSnapshots = try tc.context.fetch(snapshotDescriptor)
    #expect(allSnapshots.count == 1)
  }

  @Test("Importing adds to existing snapshot if one exists for date")
  func importAddsToExistingSnapshot() throws {
    let tc = createTestContext()

    // Create existing snapshot with one asset
    let date = makeDate(year: 2025, month: 6, day: 15)
    let existingSnapshot = Snapshot(date: date)
    tc.context.insert(existingSnapshot)
    let existingAsset = Asset(name: "GOOG", platform: "Schwab")
    tc.context.insert(existingAsset)
    let existingSav = SnapshotAssetValue(marketValue: 20000)
    existingSav.snapshot = existingSnapshot
    existingSav.asset = existingAsset
    tc.context.insert(existingSav)

    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.snapshotDate = date

    // Import CSV with different assets (no overlap)
    let csv = csvData(
      """
      Asset Name,Market Value,Platform
      AAPL,15000,Firstrade
      """)
    viewModel.loadCSVData(csv)

    let snapshot = viewModel.executeImport()

    #expect(snapshot != nil)
    #expect(snapshot?.id == existingSnapshot.id)

    // Should now have 2 asset values on the same snapshot
    let savDescriptor = FetchDescriptor<SnapshotAssetValue>()
    let allSavs = try tc.context.fetch(savDescriptor)
    #expect(allSavs.count == 2)

    // Still just 1 snapshot
    let snapshotDescriptor = FetchDescriptor<Snapshot>()
    let allSnapshots = try tc.context.fetch(snapshotDescriptor)
    #expect(allSnapshots.count == 1)
  }

  @Test("Importing creates new Asset records for unknown assets")
  func importCreatesNewAssets() throws {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validAssetCSVData())

    let snapshot = viewModel.executeImport()
    #expect(snapshot != nil)

    let assetDescriptor = FetchDescriptor<Asset>()
    let assets = try tc.context.fetch(assetDescriptor)
    #expect(assets.count == 3)
  }

  @Test("Importing reuses existing Asset records for matching name and platform")
  func importReusesExistingAssets() throws {
    let tc = createTestContext()

    // Pre-create AAPL on Interactive Brokers
    let existingAsset = Asset(name: "AAPL", platform: "Interactive Brokers")
    tc.context.insert(existingAsset)

    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validAssetCSVData())

    let snapshot = viewModel.executeImport()
    #expect(snapshot != nil)

    // AAPL should be reused, not duplicated; VTI and Bitcoin are new
    let assetDescriptor = FetchDescriptor<Asset>()
    let assets = try tc.context.fetch(assetDescriptor)
    #expect(assets.count == 3)

    let aaplAssets = assets.filter { $0.normalizedName == "aapl" }
    #expect(aaplAssets.count == 1)
    #expect(aaplAssets.first?.id == existingAsset.id)
  }

  @Test("Importing creates SnapshotAssetValues for each row")
  func importCreatesSnapshotAssetValues() throws {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validAssetCSVData())

    let snapshot = viewModel.executeImport()
    #expect(snapshot != nil)

    let savDescriptor = FetchDescriptor<SnapshotAssetValue>()
    let allSavs = try tc.context.fetch(savDescriptor)
    #expect(allSavs.count == 3)

    // Verify values
    let aaplSav = allSavs.first { $0.asset?.normalizedName == "aapl" }
    #expect(aaplSav?.marketValue == Decimal(15000))
  }

  @Test("Importing assigns category to all assets when category selected")
  func importAssignsCategory() throws {
    let tc = createTestContext()

    let equities = Category(name: "Equities")
    tc.context.insert(equities)

    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.selectedCategory = equities
    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validAssetCSVData())

    let snapshot = viewModel.executeImport()
    #expect(snapshot != nil)

    let assetDescriptor = FetchDescriptor<Asset>()
    let assets = try tc.context.fetch(assetDescriptor)
    for asset in assets {
      #expect(asset.category?.id == equities.id)
    }
  }

  @Test("Importing overrides existing category when import category is selected")
  func importOverridesCategory() throws {
    let tc = createTestContext()

    let bonds = Category(name: "Bonds")
    tc.context.insert(bonds)
    let equities = Category(name: "Equities")
    tc.context.insert(equities)

    // Pre-create AAPL assigned to Bonds
    let existingAsset = Asset(name: "AAPL", platform: "Interactive Brokers")
    existingAsset.category = bonds
    tc.context.insert(existingAsset)

    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.selectedCategory = equities
    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validAssetCSVData())

    let snapshot = viewModel.executeImport()
    #expect(snapshot != nil)

    // AAPL should now be in Equities
    let assetDescriptor = FetchDescriptor<Asset>()
    let assets = try tc.context.fetch(assetDescriptor)
    let aapl = assets.first { $0.normalizedName == "aapl" }
    #expect(aapl?.category?.id == equities.id)
  }

  @Test("Import returns created snapshot for navigation")
  func importReturnsSnapshot() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validAssetCSVData())

    let snapshot = viewModel.executeImport()

    #expect(snapshot != nil)
    #expect(
      snapshot?.date
        == Calendar.current.startOfDay(
          for: makeDate(year: 2025, month: 6, day: 15)))
  }

  // MARK: - Import Execution: Cash Flow CSV

  @Test("Importing cash flows creates CashFlowOperations on snapshot")
  func importCreatesCashFlowOperations() throws {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.importType = .cashFlows

    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validCashFlowCSVData())

    let snapshot = viewModel.executeImport()
    #expect(snapshot != nil)

    let cfDescriptor = FetchDescriptor<CashFlowOperation>()
    let allOps = try tc.context.fetch(cfDescriptor)
    #expect(allOps.count == 2)

    let salary = allOps.first { $0.cashFlowDescription == "Salary deposit" }
    #expect(salary?.amount == Decimal(50000))

    let transfer = allOps.first { $0.cashFlowDescription == "Emergency fund transfer" }
    #expect(transfer?.amount == Decimal(-10000))
  }

  @Test("Importing cash flows to existing snapshot adds to it")
  func importCashFlowsToExistingSnapshot() throws {
    let tc = createTestContext()

    // Create existing snapshot
    let date = makeDate(year: 2025, month: 6, day: 15)
    let existingSnapshot = Snapshot(date: date)
    tc.context.insert(existingSnapshot)

    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.importType = .cashFlows
    viewModel.snapshotDate = date
    viewModel.loadCSVData(validCashFlowCSVData())

    let snapshot = viewModel.executeImport()

    #expect(snapshot != nil)
    #expect(snapshot?.id == existingSnapshot.id)

    let cfDescriptor = FetchDescriptor<CashFlowOperation>()
    let allOps = try tc.context.fetch(cfDescriptor)
    #expect(allOps.count == 2)
  }

  // MARK: - State Management

  @Test("isImportDisabled is true when no rows loaded")
  func importDisabledWhenNoRows() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    #expect(viewModel.isImportDisabled)
  }

  @Test("isImportDisabled is true when validation errors exist")
  func importDisabledWhenErrors() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    // Load CSV with errors
    let csv = csvData(
      """
      Asset Name,Market Value
      ,15000
      """)
    viewModel.loadCSVData(csv)

    #expect(viewModel.isImportDisabled)
  }

  @Test("isImportDisabled is false when valid rows and no errors")
  func importEnabledWhenValid() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)

    viewModel.loadCSVData(validAssetCSVData())

    #expect(viewModel.isImportDisabled == false)
  }

  @Test("hasUnsavedChanges is true when file loaded but not imported")
  func hasUnsavedChangesWhenFileLoaded() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.loadCSVData(validAssetCSVData())

    #expect(viewModel.hasUnsavedChanges)
  }

  @Test("hasUnsavedChanges is false after import")
  func hasUnsavedChangesFalseAfterImport() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validAssetCSVData())
    _ = viewModel.executeImport()

    #expect(viewModel.hasUnsavedChanges == false)
  }

  @Test("Reset clears all state")
  func resetClearsState() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.loadCSVData(validAssetCSVData())
    #expect(!viewModel.assetPreviewRows.isEmpty)

    viewModel.reset()

    #expect(viewModel.assetPreviewRows.isEmpty)
    #expect(viewModel.cashFlowPreviewRows.isEmpty)
    #expect(viewModel.validationErrors.isEmpty)
    #expect(viewModel.validationWarnings.isEmpty)
    #expect(viewModel.selectedFileURL == nil)
    #expect(viewModel.selectedPlatform == nil)
    #expect(viewModel.selectedCategory == nil)
    #expect(viewModel.importError == nil)
    #expect(viewModel.hasUnsavedChanges == false)
  }

  // MARK: - Existing Platforms List

  @Test("Existing platforms list includes platforms from all assets")
  func existingPlatformsList() {
    let tc = createTestContext()

    let asset1 = Asset(name: "AAPL", platform: "Firstrade")
    let asset2 = Asset(name: "BTC", platform: "Coinbase")
    let asset3 = Asset(name: "VTI", platform: "Firstrade")
    tc.context.insert(asset1)
    tc.context.insert(asset2)
    tc.context.insert(asset3)

    let viewModel = ImportViewModel(modelContext: tc.context)
    let platforms = viewModel.existingPlatforms()

    #expect(platforms.contains("Firstrade"))
    #expect(platforms.contains("Coinbase"))
    #expect(platforms.count == 2)
  }

  // MARK: - Existing Categories List

  @Test("Existing categories list includes all categories")
  func existingCategoriesList() throws {
    let tc = createTestContext()

    let cat1 = Category(name: "Equities")
    let cat2 = Category(name: "Bonds")
    tc.context.insert(cat1)
    tc.context.insert(cat2)

    let viewModel = ImportViewModel(modelContext: tc.context)
    let categories = viewModel.existingCategories()

    #expect(categories.count == 2)
  }

  // MARK: - Only Included Rows Are Imported

  @Test("Only included asset rows are imported")
  func onlyIncludedAssetRowsImported() throws {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validAssetCSVData())

    // Remove the first row (AAPL)
    viewModel.removeAssetPreviewRow(at: 0)

    let snapshot = viewModel.executeImport()
    #expect(snapshot != nil)

    let savDescriptor = FetchDescriptor<SnapshotAssetValue>()
    let allSavs = try tc.context.fetch(savDescriptor)
    #expect(allSavs.count == 2)

    // AAPL should not be in the snapshot
    let aaplSav = allSavs.first { $0.asset?.normalizedName == "aapl" }
    #expect(aaplSav == nil)
  }

  @Test("Only included cash flow rows are imported")
  func onlyIncludedCashFlowRowsImported() throws {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)
    viewModel.importType = .cashFlows

    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validCashFlowCSVData())

    // Remove the first row
    viewModel.removeCashFlowPreviewRow(at: 0)

    let snapshot = viewModel.executeImport()
    #expect(snapshot != nil)

    let cfDescriptor = FetchDescriptor<CashFlowOperation>()
    let allOps = try tc.context.fetch(cfDescriptor)
    #expect(allOps.count == 1)
    #expect(allOps.first?.cashFlowDescription == "Emergency fund transfer")
  }

  // MARK: - Import With No Category (Uncategorized)

  @Test("Import without category leaves assets uncategorized")
  func importWithoutCategoryLeavesUncategorized() throws {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.selectedCategory = nil
    viewModel.loadCSVData(validAssetCSVData())

    let snapshot = viewModel.executeImport()
    #expect(snapshot != nil)

    let assetDescriptor = FetchDescriptor<Asset>()
    let assets = try tc.context.fetch(assetDescriptor)
    for asset in assets {
      #expect(asset.category == nil)
    }
  }

  // MARK: - Snapshot Date Change Re-triggers Duplicate Detection

  @Test("Changing snapshot date re-triggers duplicate detection against existing snapshot")
  func changingSnapshotDateRetriggersDuplicateDetection() {
    let tc = createTestContext()

    // Create existing snapshot on June 15 with AAPL
    let date1 = makeDate(year: 2025, month: 6, day: 15)
    let snapshot = Snapshot(date: date1)
    tc.context.insert(snapshot)
    let asset = Asset(name: "AAPL", platform: "Interactive Brokers")
    tc.context.insert(asset)
    let sav = SnapshotAssetValue(marketValue: 10000)
    sav.snapshot = snapshot
    sav.asset = asset
    tc.context.insert(sav)

    let viewModel = ImportViewModel(modelContext: tc.context)

    // Set date to June 16 (no existing snapshot) and load CSV with AAPL
    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 16)
    viewModel.loadCSVData(validAssetCSVData())

    // No duplicate error on June 16
    #expect(viewModel.validationErrors.isEmpty)

    // Now change date to June 15 where AAPL already exists
    viewModel.snapshotDate = date1

    // Should detect duplicate AAPL on the new date
    let hasDuplicateError = viewModel.validationErrors.contains {
      $0.message.contains("AAPL")
    }
    #expect(hasDuplicateError)
  }

  // MARK: - Revalidation Preserves Parsing Errors

  @Test("Removing a row preserves non-duplicate parsing errors from initial load")
  func removeRowPreservesParsingErrors() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    // CSV with: one empty-name error row, two AAPL duplicates, and one valid row
    // The empty-name row produces a parsing error but is NOT a preview row.
    // The two AAPLs are preview rows and produce a within-CSV duplicate error.
    let csv = csvData(
      """
      Asset Name,Market Value
      ,15000
      AAPL,20000
      AAPL,25000
      VTI,10000
      """)
    viewModel.loadCSVData(csv)

    // Should have parsing error (empty name) AND duplicate error (two AAPLs)
    let initialErrors = viewModel.validationErrors
    #expect(initialErrors.count >= 2)
    let hasEmptyNameError = initialErrors.contains {
      $0.message.lowercased().contains("empty")
    }
    #expect(hasEmptyNameError)

    // Preview rows: AAPL(0), AAPL(1), VTI(2) - 3 rows
    #expect(viewModel.assetPreviewRows.count == 3)

    // Remove one of the AAPL rows (index 1)
    viewModel.removeAssetPreviewRow(at: 1)

    // After revalidation:
    // - Duplicate error should be gone (only one AAPL now)
    // - But the parsing error for empty name should still be present
    let hasEmptyNameErrorAfter = viewModel.validationErrors.contains {
      $0.message.lowercased().contains("empty")
    }
    #expect(hasEmptyNameErrorAfter)
  }

  // MARK: - Import Sets importedSnapshot for Navigation

  @Test("Successful import sets importedSnapshot for navigation")
  func successfulImportSetsImportedSnapshot() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    #expect(viewModel.importedSnapshot == nil)

    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validAssetCSVData())

    let snapshot = viewModel.executeImport()

    #expect(snapshot != nil)
    #expect(viewModel.importedSnapshot != nil)
    #expect(viewModel.importedSnapshot?.id == snapshot?.id)
  }

  @Test("Failed import does not set importedSnapshot")
  func failedImportDoesNotSetImportedSnapshot() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    // Set future date to cause failure
    let futureDate = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    viewModel.snapshotDate = futureDate
    viewModel.loadCSVData(validAssetCSVData())

    let result = viewModel.executeImport()

    #expect(result == nil)
    #expect(viewModel.importedSnapshot == nil)
  }

  @Test("Reset clears importedSnapshot")
  func resetClearsImportedSnapshot() {
    let tc = createTestContext()
    let viewModel = ImportViewModel(modelContext: tc.context)

    viewModel.snapshotDate = makeDate(year: 2025, month: 6, day: 15)
    viewModel.loadCSVData(validAssetCSVData())
    _ = viewModel.executeImport()
    #expect(viewModel.importedSnapshot != nil)

    viewModel.reset()
    #expect(viewModel.importedSnapshot == nil)
  }
}
