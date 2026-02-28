//
//  SnapshotListViewModelCurrencyTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/22.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("SnapshotListViewModel Currency Tests")
@MainActor
struct SnapshotListViewModelCurrencyTests {

  private struct TestContext {
    let container: ModelContainer
    let context: ModelContext
  }

  private func createTestContext() -> TestContext {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    return TestContext(container: container, context: context)
  }

  private func makeExchangeRate(
    base: String = "usd",
    rates: [String: Double]
  ) throws -> ExchangeRate {
    let ratesJSON = try JSONEncoder().encode(rates)
    return ExchangeRate(baseCurrency: base, ratesJSON: ratesJSON, fetchDate: Date())
  }

  @Test("Snapshot row total converts multi-currency assets to display currency")
  func testSnapshotRowTotalConvertsToDisplayCurrency() throws {
    let tc = createTestContext()

    let settings = SettingsService.createForTesting()
    settings.mainCurrency = "usd"

    let snapshot = Snapshot(date: Date())
    tc.context.insert(snapshot)

    let assetUSD = Asset(name: "US Stock")
    assetUSD.currency = "usd"
    tc.context.insert(assetUSD)

    let assetTWD = Asset(name: "TW Stock")
    assetTWD.currency = "twd"
    tc.context.insert(assetTWD)

    let sav1 = SnapshotAssetValue(marketValue: Decimal(1000))
    sav1.snapshot = snapshot
    sav1.asset = assetUSD
    tc.context.insert(sav1)

    // 31500 TWD → 1000 USD at rate 31.5
    let sav2 = SnapshotAssetValue(marketValue: Decimal(31500))
    sav2.snapshot = snapshot
    sav2.asset = assetTWD
    tc.context.insert(sav2)

    let er = try makeExchangeRate(rates: ["twd": 31.5])
    er.snapshot = snapshot
    tc.context.insert(er)

    let vm = SnapshotListViewModel(modelContext: tc.context, settingsService: settings)
    let rowData = vm.snapshotRowData(for: snapshot)

    // 1000 USD + 31500/31.5 USD = 2000 USD
    #expect(rowData.totalValue == Decimal(2000))
  }
}
