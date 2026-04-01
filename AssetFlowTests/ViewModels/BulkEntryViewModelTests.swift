//  AssetFlow — snapshot-based portfolio management for macOS.
//  Copyright (C) 2026 Jen-Chien Chang
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

// swiftlint:disable file_length

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("BulkEntryRow Tests")
@MainActor
struct BulkEntryRowTests {

  @Test("isUpdated is true when included and has valid decimal value")
  func isUpdatedWithValidValue() {
    var row = makeBulkEntryRow()
    row.newValueText = "1234.56"
    row.isIncluded = true
    #expect(row.isUpdated == true)
    #expect(row.isPending == false)
    #expect(row.hasValidationError == false)
  }

  @Test("isPending is true when included and value text is empty")
  func isPendingWhenEmpty() {
    var row = makeBulkEntryRow()
    row.newValueText = ""
    row.isIncluded = true
    #expect(row.isPending == true)
    #expect(row.isUpdated == false)
  }

  @Test("hasValidationError is true when text is non-empty but not a valid decimal")
  func hasValidationErrorWithInvalidText() {
    var row = makeBulkEntryRow()
    row.newValueText = "abc"
    row.isIncluded = true
    #expect(row.hasValidationError == true)
    #expect(row.isPending == true)
    #expect(row.isUpdated == false)
  }

  @Test("excluded row is neither updated nor pending")
  func excludedRowState() {
    var row = makeBulkEntryRow()
    row.newValueText = "100"
    row.isIncluded = false
    #expect(row.isUpdated == false)
    #expect(row.isPending == false)
  }

  @Test("newValue parses valid decimal string")
  func newValueParsesDecimal() {
    var row = makeBulkEntryRow()
    row.newValueText = "42.50"
    #expect(row.newValue == Decimal(string: "42.50"))
  }

  @Test("newValue returns nil for invalid string")
  func newValueReturnsNilForInvalid() {
    var row = makeBulkEntryRow()
    row.newValueText = "not-a-number"
    #expect(row.newValue == nil)
  }

  @Test("hasZeroValueError is true when included and value is 0")
  func hasZeroValueErrorWhenZero() {
    var row = makeBulkEntryRow()
    row.newValueText = "0"
    row.isIncluded = true
    #expect(row.hasZeroValueError == true)
    #expect(row.isUpdated == false)
  }

  @Test("hasZeroValueError is false for non-zero values")
  func hasZeroValueErrorFalseForNonZero() {
    var row = makeBulkEntryRow()
    row.newValueText = "100"
    row.isIncluded = true
    #expect(row.hasZeroValueError == false)
    #expect(row.isUpdated == true)
  }

  @Test("hasZeroValueError is false for excluded rows with zero value")
  func hasZeroValueErrorFalseWhenExcluded() {
    var row = makeBulkEntryRow()
    row.newValueText = "0"
    row.isIncluded = false
    #expect(row.hasZeroValueError == false)
  }

  @Test("isNewRow is true only for manualNew source")
  func isNewRowOnlyForManualNew() {
    let manualRow = makeBulkEntryRow(source: .manual)
    let csvRow = makeBulkEntryRow(source: .csv)
    let manualNewRow = makeBulkEntryRow(source: .manualNew)

    #expect(manualRow.isNewRow == false)
    #expect(csvRow.isNewRow == false)
    #expect(manualNewRow.isNewRow == true)
  }

  @Test("hasEmptyName is true only for manualNew with whitespace-only name")
  func hasEmptyNameOnlyForManualNewWithEmptyName() {
    let manualNewEmpty = makeBulkEntryRow(assetName: "", source: .manualNew)
    let manualNewWhitespace = makeBulkEntryRow(assetName: "  ", source: .manualNew)
    let manualNewNamed = makeBulkEntryRow(assetName: "Stock A", source: .manualNew)
    let manualEmpty = makeBulkEntryRow(assetName: "", source: .manual)

    #expect(manualNewEmpty.hasEmptyName == true)
    #expect(manualNewWhitespace.hasEmptyName == true)
    #expect(manualNewNamed.hasEmptyName == false)
    #expect(manualEmpty.hasEmptyName == false)
  }

  @Test("isNewAsset is true when asset is nil")
  func isNewAssetWhenAssetNil() {
    let withoutAsset = makeBulkEntryRow(asset: nil)
    #expect(withoutAsset.isNewAsset == true)
  }

  // MARK: - Helpers

  private func makeBulkEntryRow(
    asset: Asset? = nil,
    assetName: String = "Test Asset",
    platform: String = "Test Platform",
    currency: String = "USD",
    previousValue: Decimal? = Decimal(100),
    source: ValueSource = .manual
  ) -> BulkEntryRow {
    BulkEntryRow(
      id: UUID(),
      asset: asset,
      assetName: assetName,
      platform: platform,
      currency: currency,
      previousValue: previousValue,
      newValueText: "",
      isIncluded: true,
      source: source,
      categoryName: nil
    )
  }
}

@Suite("BulkEntryViewModel Tests")
@MainActor
// swiftlint:disable:next type_body_length
struct BulkEntryViewModelTests {

  @Test("init loads rows from latest snapshot before given date")
  func initLoadsFromLatestSnapshot() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(name: "Stock A", platform: "Vanguard", currency: "USD", value: Decimal(1000)),
        TestAssetData(name: "Bond B", platform: "Vanguard", currency: "USD", value: Decimal(2000)),
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    #expect(viewModel.rows.count == 2)
    #expect(viewModel.rows[0].assetName == "Bond B")  // alphabetical
    #expect(viewModel.rows[1].assetName == "Stock A")
    #expect(viewModel.rows[0].previousValue == Decimal(2000))
  }

  @Test("init produces empty rows when no previous snapshot exists")
  func initEmptyWhenNoPreviousSnapshot() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    #expect(viewModel.rows.isEmpty)
  }

  @Test("platformGroups groups and sorts rows by platform then asset name")
  func platformGroupsSortCorrectly() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(
          name: "Zebra Fund", platform: "Vanguard", currency: "USD", value: Decimal(100)),
        TestAssetData(
          name: "Alpha ETF", platform: "Vanguard", currency: "USD", value: Decimal(200)),
        TestAssetData(name: "Taiwan 50", platform: "Cathay", currency: "TWD", value: Decimal(300)),
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let groups = viewModel.platformGroups
    #expect(groups.count == 2)
    #expect(groups[0].platform == "Cathay")
    #expect(groups[1].platform == "Vanguard")
    #expect(groups[1].rows[0].assetName == "Alpha ETF")
    #expect(groups[1].rows[1].assetName == "Zebra Fund")
  }

  @Test("counts reflect row states correctly")
  func countsReflectStates() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100)),
        TestAssetData(name: "B", platform: "P1", currency: "USD", value: Decimal(200)),
        TestAssetData(name: "C", platform: "P1", currency: "USD", value: Decimal(300)),
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    // Initially all pending
    #expect(viewModel.pendingCount == 3)
    #expect(viewModel.updatedCount == 0)
    #expect(viewModel.excludedCount == 0)

    // Update one
    viewModel.rows[0].newValueText = "150"
    #expect(viewModel.updatedCount == 1)
    #expect(viewModel.pendingCount == 2)

    // Exclude one
    viewModel.toggleInclude(rowID: viewModel.rows[2].id)
    #expect(viewModel.excludedCount == 1)
    #expect(viewModel.pendingCount == 1)
  }

  @Test("canSave is true when rows are pending (they will be saved as 0)")
  func canSaveTrueWhenPending() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    #expect(viewModel.canSave == true)
  }

  @Test("canSave is false when all rows are excluded")
  func canSaveFalseWhenAllExcluded() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.toggleInclude(rowID: viewModel.rows[0].id)

    #expect(viewModel.canSave == false)
  }

  @Test("saveSnapshot creates snapshot with asset values for updated rows")
  func saveSnapshotCreatesValues() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(name: "Stock A", platform: "Vanguard", currency: "USD", value: Decimal(1000)),
        TestAssetData(name: "Bond B", platform: "Vanguard", currency: "USD", value: Decimal(2000)),
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows[0].newValueText = "2100"
    viewModel.rows[1].newValueText = "1100"

    let snapshot = try viewModel.saveSnapshot()

    #expect(snapshot.date == Calendar.current.startOfDay(for: makeDate(2026, 3, 15)))
    let values = snapshot.assetValues ?? []
    #expect(values.count == 2)
    let sortedValues = values.sorted { ($0.asset?.name ?? "") < ($1.asset?.name ?? "") }
    #expect(sortedValues[0].marketValue == Decimal(2100))
    #expect(sortedValues[1].marketValue == Decimal(1100))
  }

  @Test("saveSnapshot saves pending rows with value 0")
  func saveSnapshotPendingRowsGetZero() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(name: "Stock A", platform: "Vanguard", currency: "USD", value: Decimal(1000))
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    // Leave newValueText empty — pending

    let snapshot = try viewModel.saveSnapshot()
    let values = snapshot.assetValues ?? []
    #expect(values.count == 1)
    #expect(values[0].marketValue == Decimal(0))
  }

  @Test("saveSnapshot excludes unchecked rows")
  func saveSnapshotExcludesUnchecked() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(name: "Stock A", platform: "Vanguard", currency: "USD", value: Decimal(1000)),
        TestAssetData(name: "Bond B", platform: "Vanguard", currency: "USD", value: Decimal(2000)),
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows[0].newValueText = "2100"
    viewModel.toggleInclude(rowID: viewModel.rows[1].id)

    let snapshot = try viewModel.saveSnapshot()
    let values = snapshot.assetValues ?? []
    #expect(values.count == 1)
    #expect(values[0].asset?.name == "Bond B")
  }

  @Test("saveSnapshot throws when all rows excluded")
  func saveSnapshotThrowsWhenAllExcluded() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(name: "Stock A", platform: "Vanguard", currency: "USD", value: Decimal(1000))
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.toggleInclude(rowID: viewModel.rows[0].id)

    #expect(throws: SnapshotError.self) {
      try viewModel.saveSnapshot()
    }
  }

  @Test("saveSnapshot creates new assets from CSV-only rows")
  func saveSnapshotCreatesNewAssetsFromCSV() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // No previous snapshot — add a CSV row manually
    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows.append(
      BulkEntryRow(
        id: UUID(),
        asset: nil,
        assetName: "New Fund",
        platform: "Fidelity",
        currency: "EUR",
        previousValue: nil,
        newValueText: "5000",
        isIncluded: true,
        source: .csv,
        categoryName: nil
      ))

    let snapshot = try viewModel.saveSnapshot()
    let values = snapshot.assetValues ?? []
    #expect(values.count == 1)
    #expect(values[0].marketValue == Decimal(5000))
    #expect(values[0].asset?.name == "New Fund")
    #expect(values[0].asset?.platform == "Fidelity")
    #expect(values[0].asset?.currency == "EUR")
  }

  @Test("importCSV fills matching rows with CSV values")
  func importCSVFillsMatchingRows() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(name: "Stock A", platform: "Vanguard", currency: "USD", value: Decimal(1000)),
        TestAssetData(name: "Bond B", platform: "Vanguard", currency: "USD", value: Decimal(2000)),
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let csvData = "Asset Name,Market Value\nStock A,1500\n".data(using: .utf8)!
    let result = viewModel.importCSV(data: csvData, forPlatform: "Vanguard")

    #expect(result.errors.isEmpty)
    #expect(result.matchedCount == 1)
    let stockRow = viewModel.rows.first(where: { $0.assetName == "Stock A" })
    #expect(stockRow?.newValueText == "1500")
    #expect(stockRow?.source == .csv)
    let bondRow = viewModel.rows.first(where: { $0.assetName == "Bond B" })
    #expect(bondRow?.newValueText == "")
    #expect(bondRow?.source == .manual)
  }

  @Test("importCSV appends new rows for unmatched CSV assets")
  func importCSVAppendsNewRows() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(name: "Stock A", platform: "Vanguard", currency: "USD", value: Decimal(1000))
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let csvData = "Asset Name,Market Value,Currency\nNew Fund,3000,EUR\n".data(using: .utf8)!
    let result = viewModel.importCSV(data: csvData, forPlatform: "Vanguard")

    #expect(result.errors.isEmpty)
    #expect(result.newCount == 1)
    #expect(viewModel.rows.count == 2)
    let newRow = viewModel.rows.first(where: { $0.assetName == "New Fund" })
    #expect(newRow != nil)
    #expect(newRow?.newValueText == "3000")
    #expect(newRow?.source == .csv)
    #expect(newRow?.asset == nil)
    #expect(newRow?.currency == "EUR")
    #expect(newRow?.previousValue == nil)
    #expect(newRow?.platform == "Vanguard")
  }

  @Test("re-importing CSV for same platform replaces previous CSV values")
  func reImportCSVReplacesValues() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(name: "Stock A", platform: "Vanguard", currency: "USD", value: Decimal(1000))
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let csv1 = "Asset Name,Market Value\nStock A,1500\n".data(using: .utf8)!
    viewModel.importCSV(data: csv1, forPlatform: "Vanguard")
    #expect(viewModel.rows.first?.newValueText == "1500")

    let csv2 = "Asset Name,Market Value\nStock A,1800\n".data(using: .utf8)!
    viewModel.importCSV(data: csv2, forPlatform: "Vanguard")
    #expect(viewModel.rows.first?.newValueText == "1800")
  }

  // MARK: - Add Manual Row / Platform Tests

  @Test("addManualRow appends row with correct platform and defaults")
  func addManualRowAppendsCorrectRow() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let rowID = viewModel.addManualRow(forPlatform: "Vanguard")

    #expect(viewModel.rows.count == 1)
    let row = viewModel.rows[0]
    #expect(row.id == rowID)
    #expect(row.platform == "Vanguard")
    #expect(row.assetName == "")
    #expect(row.source == .manualNew)
    #expect(row.asset == nil)
    #expect(row.previousValue == nil)
    #expect(row.isIncluded == true)
    #expect(row.currency == SettingsService.shared.mainCurrency)
  }

  @Test("addPlatform creates new group with one empty row")
  func addPlatformCreatesGroup() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let rowID = viewModel.addPlatform(name: "Fidelity")

    #expect(rowID != nil)
    #expect(viewModel.platformGroups.count == 1)
    #expect(viewModel.platformGroups[0].platform == "Fidelity")
    #expect(viewModel.platformGroups[0].rows.count == 1)
    #expect(viewModel.platformGroups[0].rows[0].source == .manualNew)
  }

  @Test("addPlatform rejects duplicate platform name (case-insensitive)")
  func addPlatformRejectsDuplicate() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(name: "A", platform: "Vanguard", currency: "USD", value: Decimal(100))
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let result = viewModel.addPlatform(name: "vanguard")
    #expect(result == nil)
    #expect(viewModel.platformGroups.count == 1)
  }

  @Test("addPlatform rejects empty or whitespace name")
  func addPlatformRejectsEmpty() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    #expect(viewModel.addPlatform(name: "") == nil)
    #expect(viewModel.addPlatform(name: "  ") == nil)
    #expect(viewModel.rows.isEmpty)
  }

  @Test("removeManualRow removes manualNew row but not manual or csv rows")
  func removeManualRowOnlyRemovesManualNew() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    let existingRowID = viewModel.rows[0].id
    let newRowID = viewModel.addManualRow(forPlatform: "P1")

    #expect(viewModel.rows.count == 2)

    // Cannot remove existing row
    viewModel.removeManualRow(rowID: existingRowID)
    #expect(viewModel.rows.count == 2)

    // Can remove manualNew row
    viewModel.removeManualRow(rowID: newRowID)
    #expect(viewModel.rows.count == 1)
    #expect(viewModel.rows[0].id == existingRowID)
  }

  @Test("canSave is false when included manualNew row has empty name")
  func canSaveFalseWithEmptyNameNewRow() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.addPlatform(name: "Fidelity")

    #expect(viewModel.canSave == false)
  }

  @Test("hasUnsavedChanges is true when manualNew rows exist")
  func hasUnsavedChangesWithManualNewRows() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    #expect(viewModel.hasUnsavedChanges == false)

    viewModel.addPlatform(name: "Fidelity")
    #expect(viewModel.hasUnsavedChanges == true)
  }

  @Test("canSave allows duplicate asset names (validated at save time instead)")
  func canSaveAllowsDuplicateNames() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.addManualRow(forPlatform: "P1")
    viewModel.addManualRow(forPlatform: "P1")
    viewModel.rows[0].assetName = "Stock A"
    viewModel.rows[0].newValueText = "100"
    viewModel.rows[1].assetName = "stock a"
    viewModel.rows[1].newValueText = "200"

    // canSave is true because duplicate names are now validated at save time
    #expect(viewModel.canSave == true)
  }

  @Test("saveSnapshot throws on duplicate asset names within same platform")
  func saveSnapshotThrowsOnDuplicateAssetNames() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.addManualRow(forPlatform: "P1")
    viewModel.addManualRow(forPlatform: "P1")
    viewModel.rows[0].assetName = "Stock A"
    viewModel.rows[0].newValueText = "100"
    viewModel.rows[1].assetName = "stock a"
    viewModel.rows[1].newValueText = "200"

    #expect(throws: SnapshotError.self) {
      try viewModel.saveSnapshot()
    }
  }

  @Test("saveSnapshot allows same asset name in different platforms")
  func saveSnapshotAllowsSameNameDifferentPlatforms() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.addManualRow(forPlatform: "P1")
    viewModel.addManualRow(forPlatform: "P2")
    viewModel.rows[0].assetName = "Stock A"
    viewModel.rows[0].newValueText = "100"
    viewModel.rows[1].assetName = "Stock A"
    viewModel.rows[1].newValueText = "200"

    let snapshot = try viewModel.saveSnapshot()
    let values = snapshot.assetValues ?? []
    #expect(values.count == 2)
  }

  @Test("saveSnapshot allows duplicate asset names when one is excluded")
  func saveSnapshotAllowsDuplicateAssetNamesWhenOneExcluded() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.addManualRow(forPlatform: "P1")
    viewModel.addManualRow(forPlatform: "P1")
    viewModel.rows[0].assetName = "Stock A"
    viewModel.rows[0].newValueText = "100"
    viewModel.rows[1].assetName = "stock a"
    viewModel.rows[1].newValueText = "200"
    viewModel.toggleInclude(rowID: viewModel.rows[1].id)

    let snapshot = try viewModel.saveSnapshot()
    let values = snapshot.assetValues ?? []
    #expect(values.count == 1)
  }

  @Test("saveSnapshot creates asset for manualNew row")
  func saveSnapshotCreatesAssetForManualNewRow() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.addPlatform(name: "Fidelity")
    viewModel.rows[0].assetName = "New Fund"
    viewModel.rows[0].currency = "EUR"
    viewModel.rows[0].newValueText = "5000"

    let snapshot = try viewModel.saveSnapshot()
    let values = snapshot.assetValues ?? []
    #expect(values.count == 1)
    #expect(values[0].marketValue == Decimal(5000))
    #expect(values[0].asset?.name == "New Fund")
    #expect(values[0].asset?.platform == "Fidelity")
    #expect(values[0].asset?.currency == "EUR")
  }

  @Test("saveSnapshot resolves categoryName to category for new-asset rows")
  func saveSnapshotResolvesCategoryName() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.addPlatform(name: "Fidelity")
    viewModel.rows[0].assetName = "Stock X"
    viewModel.rows[0].newValueText = "1000"
    viewModel.rows[0].categoryName = "Equities"

    let snapshot = try viewModel.saveSnapshot()
    let values = snapshot.assetValues ?? []
    #expect(values.count == 1)
    #expect(values[0].asset?.category?.name == "Equities")
  }

  @Test("importCSV matches against manualNew rows by normalized name")
  func importCSVMatchesManualNewRows() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.addPlatform(name: "Vanguard")
    viewModel.rows[0].assetName = "Stock A"

    let csvData = "Asset Name,Market Value\nStock A,1500\n".data(using: .utf8)!
    let result = viewModel.importCSV(data: csvData, forPlatform: "Vanguard")

    #expect(result.matchedCount == 1)
    #expect(result.newCount == 0)
    #expect(viewModel.rows.count == 1)
    #expect(viewModel.rows[0].newValueText == "1500")
    #expect(viewModel.rows[0].source == .csv)
  }

  // MARK: - Helpers

  private struct TestAssetData {
    let name: String
    let platform: String
    let currency: String
    let value: Decimal
  }

  private func makeDate(_ year: Int, _ month: Int, _ day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    // swiftlint:disable:next force_unwrapping
    return Calendar.current.date(from: components)!
  }

  @discardableResult
  private func createSnapshotWithAssets(
    context: ModelContext,
    date: Date,
    assets: [TestAssetData]
  ) -> (Snapshot, [Asset]) {
    let snapshot = Snapshot(date: date)
    context.insert(snapshot)

    var createdAssets: [Asset] = []
    for assetData in assets {
      let asset = Asset(name: assetData.name, platform: assetData.platform)
      asset.currency = assetData.currency
      context.insert(asset)
      let sav = SnapshotAssetValue(marketValue: assetData.value)
      sav.snapshot = snapshot
      sav.asset = asset
      context.insert(sav)
      createdAssets.append(asset)
    }

    return (snapshot, createdAssets)
  }

  // MARK: - Column Mapping Integration

  @Test("loadCSVForMapping with canonical headers does not show mapping sheet")
  func testLoadCSVForMappingCanonicalNoSheet() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(
          name: "Stock A", platform: "Vanguard", currency: "USD", value: Decimal(1000))
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let csvData = "Asset Name,Market Value\nStock A,1500\n".data(using: .utf8)!
    viewModel.loadCSVForMapping(data: csvData, forPlatform: "Vanguard")

    #expect(!viewModel.showColumnMappingSheet)
    let stockRow = viewModel.rows.first(where: { $0.assetName == "Stock A" })
    #expect(stockRow?.newValueText == "1500")
  }

  @Test("loadCSVForMapping with non-matching headers shows mapping sheet")
  func testLoadCSVForMappingNonMatchingShowsSheet() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(
          name: "Stock A", platform: "Vanguard", currency: "USD", value: Decimal(1000))
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let csvData = "Symbol,Price\nStock A,1500\n".data(using: .utf8)!
    viewModel.loadCSVForMapping(data: csvData, forPlatform: "Vanguard")

    #expect(viewModel.showColumnMappingSheet)
    #expect(viewModel.pendingRawHeaders == ["Symbol", "Price"])
    #expect(viewModel.pendingCSVPlatform == "Vanguard")
  }

  @Test("confirmColumnMapping produces correct import result and dismisses sheet")
  func testConfirmColumnMappingBulkEntry() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [
        TestAssetData(
          name: "Stock A", platform: "Vanguard", currency: "USD", value: Decimal(1000))
      ])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let csvData = "Symbol,Price\nStock A,1500\nNew Fund,3000\n".data(using: .utf8)!
    viewModel.loadCSVForMapping(data: csvData, forPlatform: "Vanguard")
    #expect(viewModel.showColumnMappingSheet)

    let mapping = CSVColumnMapping(
      schema: .asset,
      columnMap: [.assetName: 0, .marketValue: 1],
      rawHeaders: ["Symbol", "Price"])
    let result = viewModel.confirmColumnMapping(mapping)

    #expect(!viewModel.showColumnMappingSheet)
    let importResult = try #require(result)
    #expect(importResult.matchedCount == 1)
    #expect(importResult.newCount == 1)
  }

  // MARK: - Cash Flow State Tests

  @Test("addManualCashFlowRow creates row with correct defaults")
  func addManualCashFlowRowDefaults() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    let rowID = viewModel.addManualCashFlowRow()

    #expect(viewModel.cashFlowRows.count == 1)
    let row = viewModel.cashFlowRows[0]
    #expect(row.id == rowID)
    #expect(row.cashFlowDescription.isEmpty)
    #expect(row.amountText.isEmpty)
    #expect(row.currency == SettingsService.shared.mainCurrency)
    #expect(row.isIncluded == true)
    #expect(row.source == .manualNew)
  }

  @Test("removeCashFlowRow only removes manualNew rows")
  func removeCashFlowRowOnlyManualNew() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    // Add a manualNew row
    let manualID = viewModel.addManualCashFlowRow()
    viewModel.cashFlowRows[0].cashFlowDescription = "Manual Flow"

    // Add a CSV-sourced row manually
    let csvRow = BulkEntryCashFlowRow(
      id: UUID(), cashFlowDescription: "CSV Flow",
      amountText: "1000", currency: "USD",
      isIncluded: true, source: .csv)
    viewModel.cashFlowRows.append(csvRow)

    #expect(viewModel.cashFlowRows.count == 2)

    // Attempt to remove CSV row — should fail
    viewModel.removeCashFlowRow(rowID: csvRow.id)
    #expect(viewModel.cashFlowRows.count == 2)

    // Remove manualNew row — should succeed
    viewModel.removeCashFlowRow(rowID: manualID)
    #expect(viewModel.cashFlowRows.count == 1)
    #expect(viewModel.cashFlowRows[0].cashFlowDescription == "CSV Flow")
  }

  @Test("toggleCashFlowInclude toggles inclusion and clears amount")
  func toggleCashFlowInclude() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    let rowID = viewModel.addManualCashFlowRow()
    viewModel.cashFlowRows[0].cashFlowDescription = "Salary"
    viewModel.cashFlowRows[0].amountText = "5000"

    #expect(viewModel.cashFlowRows[0].isIncluded == true)
    #expect(viewModel.cashFlowRows[0].amountText == "5000")

    viewModel.toggleCashFlowInclude(rowID: rowID)
    #expect(viewModel.cashFlowRows[0].isIncluded == false)
    #expect(viewModel.cashFlowRows[0].amountText.isEmpty)

    viewModel.toggleCashFlowInclude(rowID: rowID)
    #expect(viewModel.cashFlowRows[0].isIncluded == true)
  }

  @Test("cashFlowCount reflects only included rows")
  func cashFlowCountReflectsInclusion() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    let id1 = viewModel.addManualCashFlowRow()
    viewModel.addManualCashFlowRow()

    #expect(viewModel.cashFlowCount == 2)

    viewModel.toggleCashFlowInclude(rowID: id1)
    #expect(viewModel.cashFlowCount == 1)
  }

  @Test("saveSnapshot throws on duplicate cash flow descriptions (case-insensitive)")
  func saveSnapshotThrowsOnDuplicateCashFlowDescriptions() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows[0].newValueText = "100"

    viewModel.addManualCashFlowRow()
    viewModel.addManualCashFlowRow()
    viewModel.cashFlowRows[0].cashFlowDescription = "Salary"
    viewModel.cashFlowRows[0].amountText = "5000"
    viewModel.cashFlowRows[1].cashFlowDescription = "salary"
    viewModel.cashFlowRows[1].amountText = "3000"

    #expect(throws: SnapshotError.self) {
      try viewModel.saveSnapshot()
    }
  }

  @Test("saveSnapshot allows duplicate descriptions when one is excluded")
  func saveSnapshotAllowsDuplicateWhenExcluded() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows[0].newValueText = "100"

    viewModel.addManualCashFlowRow()
    viewModel.addManualCashFlowRow()
    viewModel.cashFlowRows[0].cashFlowDescription = "Salary"
    viewModel.cashFlowRows[0].amountText = "5000"
    viewModel.cashFlowRows[1].cashFlowDescription = "salary"
    viewModel.cashFlowRows[1].amountText = "3000"
    viewModel.toggleCashFlowInclude(rowID: viewModel.cashFlowRows[1].id)

    let snapshot = try viewModel.saveSnapshot()
    let operations = snapshot.cashFlowOperations ?? []
    #expect(operations.count == 1)
    #expect(operations[0].cashFlowDescription == "Salary")
  }

  @Test("canSave is false when cash flow row has validation error")
  func canSaveFalseWithCashFlowValidationError() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows[0].newValueText = "100"

    // Add cash flow with invalid amount
    viewModel.addManualCashFlowRow()
    viewModel.cashFlowRows[0].cashFlowDescription = "Salary"
    viewModel.cashFlowRows[0].amountText = "abc"

    #expect(viewModel.canSave == false)
  }

  @Test("canSave is false when cash flow has empty description")
  func canSaveFalseWithEmptyCashFlowDescription() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows[0].newValueText = "100"

    // Add cash flow with empty description
    viewModel.addManualCashFlowRow()
    viewModel.cashFlowRows[0].amountText = "5000"

    #expect(viewModel.canSave == false)
  }

  @Test("canSave is false when cash flow has empty amount")
  func canSaveFalseWithEmptyCashFlowAmount() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows[0].newValueText = "100"

    viewModel.addManualCashFlowRow()
    viewModel.cashFlowRows[0].cashFlowDescription = "Salary"
    // amountText left empty

    #expect(viewModel.canSave == false)
  }

  @Test("canSave is true with valid cash flow rows")
  func canSaveTrueWithValidCashFlowRows() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows[0].newValueText = "100"

    viewModel.addManualCashFlowRow()
    viewModel.cashFlowRows[0].cashFlowDescription = "Salary"
    viewModel.cashFlowRows[0].amountText = "5000"

    #expect(viewModel.canSave == true)
  }

  @Test("canSave is true with no cash flow rows")
  func canSaveTrueWithNoCashFlowRows() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows[0].newValueText = "100"

    #expect(viewModel.canSave == true)
  }

  @Test("hasUnsavedChanges is true when cash flow rows exist")
  func hasUnsavedChangesWithCashFlowRows() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    #expect(viewModel.hasUnsavedChanges == false)

    viewModel.addManualCashFlowRow()
    #expect(viewModel.hasUnsavedChanges == true)
  }

  // MARK: - Cash Flow CSV Import Tests

  @Test("importCashFlowCSV adds rows with csv source")
  func importCashFlowCSVAddsRows() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let csvData = "Description,Amount\nSalary,50000\nBonus,10000\n".data(using: .utf8)!
    let result = viewModel.importCashFlowCSV(data: csvData)

    #expect(result.errors.isEmpty)
    #expect(result.newCount == 2)
    #expect(viewModel.cashFlowRows.count == 2)

    let salaryRow = viewModel.cashFlowRows.first(where: {
      $0.cashFlowDescription == "Salary"
    })
    #expect(salaryRow != nil)
    #expect(salaryRow?.amountText == "50000")
    #expect(salaryRow?.source == .csv)
    #expect(salaryRow?.isIncluded == true)
  }

  @Test("importCashFlowCSV matches existing manual rows by description")
  func importCashFlowCSVMatchesManualRows() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.addManualCashFlowRow()
    viewModel.cashFlowRows[0].cashFlowDescription = "Salary"

    let csvData = "Description,Amount\nSalary,50000\n".data(using: .utf8)!
    let result = viewModel.importCashFlowCSV(data: csvData)

    #expect(result.matchedCount == 1)
    #expect(result.newCount == 0)
    #expect(viewModel.cashFlowRows.count == 1)
    #expect(viewModel.cashFlowRows[0].amountText == "50000")
    #expect(viewModel.cashFlowRows[0].source == .csv)
  }

  @Test("re-importing cash flow CSV replaces previous values")
  func reImportCashFlowCSVReplacesValues() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let csv1 = "Description,Amount\nSalary,50000\n".data(using: .utf8)!
    viewModel.importCashFlowCSV(data: csv1)
    #expect(viewModel.cashFlowRows[0].amountText == "50000")

    let csv2 = "Description,Amount\nSalary,60000\n".data(using: .utf8)!
    viewModel.importCashFlowCSV(data: csv2)
    #expect(viewModel.cashFlowRows[0].amountText == "60000")
  }

  @Test("importCashFlowCSV handles currency column and mainCurrency fallback")
  func importCashFlowCSVCurrencyHandling() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let csvData = "Description,Amount,Currency\nSalary,50000,TWD\nBonus,10000,\n".data(
      using: .utf8)!
    let result = viewModel.importCashFlowCSV(data: csvData)

    #expect(result.newCount == 2)
    let salaryRow = viewModel.cashFlowRows.first(where: {
      $0.cashFlowDescription == "Salary"
    })
    let bonusRow = viewModel.cashFlowRows.first(where: {
      $0.cashFlowDescription == "Bonus"
    })
    #expect(salaryRow?.currency == "TWD")
    #expect(bonusRow?.currency == SettingsService.shared.mainCurrency)
  }

  @Test("loadCashFlowCSVForMapping with canonical headers auto-imports")
  func loadCashFlowCSVForMappingCanonical() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let csvData = "Description,Amount\nSalary,50000\n".data(using: .utf8)!
    viewModel.loadCashFlowCSVForMapping(data: csvData)

    #expect(!viewModel.showCashFlowColumnMappingSheet)
    #expect(viewModel.cashFlowRows.count == 1)
    #expect(viewModel.cashFlowRows[0].cashFlowDescription == "Salary")
  }

  @Test("loadCashFlowCSVForMapping with non-matching headers shows sheet")
  func loadCashFlowCSVForMappingShowsSheet() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let csvData = "Label,Value\nSalary,50000\n".data(using: .utf8)!
    viewModel.loadCashFlowCSVForMapping(data: csvData)

    #expect(viewModel.showCashFlowColumnMappingSheet)
    #expect(viewModel.pendingCashFlowRawHeaders == ["Label", "Value"])
    #expect(viewModel.cashFlowRows.isEmpty)
  }

  @Test("confirmCashFlowColumnMapping imports rows and dismisses sheet")
  func confirmCashFlowColumnMappingImports() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))

    let csvData = "Label,Value\nSalary,50000\nBonus,10000\n".data(using: .utf8)!
    viewModel.loadCashFlowCSVForMapping(data: csvData)
    #expect(viewModel.showCashFlowColumnMappingSheet)

    let mapping = CSVColumnMapping(
      schema: .cashFlow,
      columnMap: [.description: 0, .amount: 1],
      rawHeaders: ["Label", "Value"])
    let result = viewModel.confirmCashFlowColumnMapping(mapping)

    #expect(!viewModel.showCashFlowColumnMappingSheet)
    let importResult = try #require(result)
    #expect(importResult.newCount == 2)
    #expect(viewModel.cashFlowRows.count == 2)
  }

  // MARK: - Save Snapshot Cash Flow Tests

  @Test("saveSnapshot creates CashFlowOperation objects with correct data")
  func saveSnapshotCreatesCashFlowOperations() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows[0].newValueText = "100"

    viewModel.addManualCashFlowRow()
    viewModel.cashFlowRows[0].cashFlowDescription = "Salary"
    viewModel.cashFlowRows[0].amountText = "50000"
    viewModel.cashFlowRows[0].currency = "TWD"

    let snapshot = try viewModel.saveSnapshot()
    let operations = snapshot.cashFlowOperations ?? []
    #expect(operations.count == 1)
    #expect(operations[0].cashFlowDescription == "Salary")
    #expect(operations[0].amount == Decimal(50000))
    #expect(operations[0].currency == "TWD")
  }

  @Test("saveSnapshot excludes unchecked cash flow rows")
  func saveSnapshotExcludesUncheckedCashFlows() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows[0].newValueText = "100"

    let id1 = viewModel.addManualCashFlowRow()
    viewModel.cashFlowRows[0].cashFlowDescription = "Salary"
    viewModel.cashFlowRows[0].amountText = "50000"

    viewModel.addManualCashFlowRow()
    viewModel.cashFlowRows[1].cashFlowDescription = "Bonus"
    viewModel.cashFlowRows[1].amountText = "10000"

    viewModel.toggleCashFlowInclude(rowID: id1)

    let snapshot = try viewModel.saveSnapshot()
    let operations = snapshot.cashFlowOperations ?? []
    #expect(operations.count == 1)
    #expect(operations[0].cashFlowDescription == "Bonus")
  }

  @Test("saveSnapshot creates no cash flow operations when no cash flow rows")
  func saveSnapshotNoCashFlowWhenEmpty() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows[0].newValueText = "100"

    let snapshot = try viewModel.saveSnapshot()
    let operations = snapshot.cashFlowOperations ?? []
    #expect(operations.isEmpty)
  }

  @Test("saveSnapshot saves cash flow with explicit zero amount")
  func saveSnapshotCashFlowExplicitZeroAmount() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    createSnapshotWithAssets(
      context: context, date: makeDate(2026, 3, 1),
      assets: [TestAssetData(name: "A", platform: "P1", currency: "USD", value: Decimal(100))])

    let viewModel = BulkEntryViewModel(
      modelContext: context, date: makeDate(2026, 3, 15))
    viewModel.rows[0].newValueText = "100"

    viewModel.addManualCashFlowRow()
    viewModel.cashFlowRows[0].cashFlowDescription = "No change"
    viewModel.cashFlowRows[0].amountText = "0"

    let snapshot = try viewModel.saveSnapshot()
    let operations = snapshot.cashFlowOperations ?? []
    #expect(operations.count == 1)
    #expect(operations[0].amount == Decimal(0))
  }
}

@Suite("BulkEntryCashFlowRow Tests")
@MainActor
struct BulkEntryCashFlowRowTests {

  @Test("amount parses valid decimal string")
  func amountParsesDecimal() {
    var row = makeCashFlowRow()
    row.amountText = "5000.50"
    #expect(row.amount == Decimal(string: "5000.50"))
  }

  @Test("amount returns nil for invalid string")
  func amountReturnsNilForInvalid() {
    var row = makeCashFlowRow()
    row.amountText = "not-a-number"
    #expect(row.amount == nil)
  }

  @Test("hasValidationError is true when text is non-empty but not a valid decimal")
  func hasValidationErrorWithInvalidText() {
    var row = makeCashFlowRow()
    row.amountText = "abc"
    #expect(row.hasValidationError == true)
  }

  @Test("hasValidationError is false when text is empty")
  func hasValidationErrorFalseWhenEmpty() {
    let row = makeCashFlowRow()
    #expect(row.hasValidationError == false)
  }

  @Test("hasEmptyDescription is true when description is empty or whitespace")
  func hasEmptyDescriptionWhenEmpty() {
    let empty = makeCashFlowRow(description: "")
    let whitespace = makeCashFlowRow(description: "  ")
    let valid = makeCashFlowRow(description: "Salary")
    #expect(empty.hasEmptyDescription == true)
    #expect(whitespace.hasEmptyDescription == true)
    #expect(valid.hasEmptyDescription == false)
  }

  @Test("negative and zero amounts parse correctly")
  func negativeAndZeroAmounts() {
    var negative = makeCashFlowRow()
    negative.amountText = "-10000"
    #expect(negative.amount == Decimal(-10000))

    var zero = makeCashFlowRow()
    zero.amountText = "0"
    #expect(zero.amount == Decimal(0))
  }

  @Test("hasEmptyAmount is true when included and amount is empty or whitespace")
  func hasEmptyAmountWhenEmpty() {
    let empty = makeCashFlowRow(amountText: "")
    let whitespace = makeCashFlowRow(amountText: "  ")
    var filled = makeCashFlowRow(amountText: "100")
    var excluded = makeCashFlowRow(amountText: "")
    excluded.isIncluded = false

    #expect(empty.hasEmptyAmount == true)
    #expect(whitespace.hasEmptyAmount == true)
    #expect(filled.hasEmptyAmount == false)
    #expect(excluded.hasEmptyAmount == false)

    filled.amountText = "0"
    #expect(filled.hasEmptyAmount == false)
  }

  private func makeCashFlowRow(
    description: String = "Test Cash Flow",
    amountText: String = "",
    currency: String = "USD",
    source: ValueSource = .manualNew
  ) -> BulkEntryCashFlowRow {
    BulkEntryCashFlowRow(
      id: UUID(), cashFlowDescription: description,
      amountText: amountText, currency: currency,
      isIncluded: true, source: source)
  }
}

@Suite("CashFlowCSVImportResult Tests")
@MainActor
struct CashFlowCSVImportResultTests {

  @Test("totalImported is sum of matched and new counts")
  func totalImported() {
    let result = CashFlowCSVImportResult(
      matchedCount: 3, newCount: 2, errors: [], parserWarnings: [])
    #expect(result.totalImported == 5)
  }

  @Test("hasErrors is true when errors exist")
  func hasErrors() {
    let result = CashFlowCSVImportResult(
      matchedCount: 0, newCount: 0, errors: ["Bad file"], parserWarnings: [])
    #expect(result.hasErrors == true)
  }

  @Test("hasWarnings is true when warnings exist")
  func hasWarnings() {
    let result = CashFlowCSVImportResult(
      matchedCount: 0, newCount: 0, errors: [], parserWarnings: ["Zero amount"])
    #expect(result.hasWarnings == true)
  }

  @Test("formattedResult uses error title when errors exist")
  func formattedResultError() {
    let result = CashFlowCSVImportResult(
      matchedCount: 0, newCount: 0, errors: ["Bad file"], parserWarnings: [])
    let formatted = result.formattedResult()
    #expect(formatted.title == String(localized: "Import Error", table: "Snapshot"))
  }

  @Test("formattedResult uses warning title when warnings exist")
  func formattedResultWarning() {
    let result = CashFlowCSVImportResult(
      matchedCount: 1, newCount: 0, errors: [], parserWarnings: ["Zero amount"])
    let formatted = result.formattedResult()
    #expect(formatted.title == String(localized: "Import Warning", table: "Snapshot"))
  }

  @Test("formattedResult uses success title when no errors or warnings")
  func formattedResultSuccess() {
    let result = CashFlowCSVImportResult(
      matchedCount: 1, newCount: 2, errors: [], parserWarnings: [])
    let formatted = result.formattedResult()
    #expect(formatted.title == String(localized: "CSV Import", table: "Snapshot"))
  }
}
