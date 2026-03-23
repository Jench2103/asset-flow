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

  // MARK: - Helpers

  private func makeBulkEntryRow(
    asset: Asset? = nil,
    assetName: String = "Test Asset",
    platform: String = "Test Platform",
    currency: String = "USD",
    previousValue: Decimal? = Decimal(100)
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
      source: .manual,
      csvCategory: nil
    )
  }
}

@Suite("BulkEntryViewModel Tests")
@MainActor
struct BulkEntryViewModelTests {

  @Test("init loads rows from latest snapshot before given date")
  func initLoadsFromLatestSnapshot() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let (snapshot, _) = createSnapshotWithAssets(
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
        csvCategory: nil
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
}
