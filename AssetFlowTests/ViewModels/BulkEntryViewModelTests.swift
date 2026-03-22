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
