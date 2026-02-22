//
//  CurrencyConversionServiceTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/22.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("CurrencyConversion Service Tests")
@MainActor
struct CurrencyConversionServiceTests {

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

  // MARK: - Convert Tests

  @Test("Convert same currency returns original value")
  func testConvertSameCurrency() throws {
    let er = try makeExchangeRate(rates: ["twd": 31.5])
    let result = CurrencyConversionService.convert(
      value: Decimal(100), from: "usd", to: "usd", using: er)
    #expect(result == Decimal(100))
  }

  @Test("Convert with nil exchange rate returns original value")
  func testConvertWithNilExchangeRate() {
    let result = CurrencyConversionService.convert(
      value: Decimal(100), from: "usd", to: "twd", using: nil)
    #expect(result == Decimal(100))
  }

  @Test("Convert base to target currency")
  func testConvertBaseToTarget() throws {
    let er = try makeExchangeRate(rates: ["twd": 31.5])
    let result = CurrencyConversionService.convert(
      value: Decimal(100), from: "usd", to: "twd", using: er)
    #expect(result == Decimal(3150))
  }

  @Test("Convert target to base currency")
  func testConvertTargetToBase() throws {
    let er = try makeExchangeRate(rates: ["twd": 31.5])
    let result = CurrencyConversionService.convert(
      value: Decimal(3150), from: "twd", to: "usd", using: er)
    #expect(result == Decimal(100))
  }

  // MARK: - Total Value Tests

  @Test("Total value with single currency needs no conversion")
  func testTotalValueSingleCurrency() throws {
    let tc = createTestContext()
    let snapshot = Snapshot(date: Date())
    tc.context.insert(snapshot)

    let asset1 = Asset(name: "Stock A")
    asset1.currency = "usd"
    tc.context.insert(asset1)

    let asset2 = Asset(name: "Stock B")
    asset2.currency = "usd"
    tc.context.insert(asset2)

    let sav1 = SnapshotAssetValue(marketValue: Decimal(1000))
    sav1.snapshot = snapshot
    sav1.asset = asset1
    tc.context.insert(sav1)

    let sav2 = SnapshotAssetValue(marketValue: Decimal(2000))
    sav2.snapshot = snapshot
    sav2.asset = asset2
    tc.context.insert(sav2)

    let er = try makeExchangeRate(rates: ["twd": 31.5])
    let total = CurrencyConversionService.totalValue(
      for: snapshot, displayCurrency: "usd", exchangeRate: er)

    #expect(total == Decimal(3000))
  }

  @Test("Total value with multiple currencies converts correctly")
  func testTotalValueMultiCurrency() throws {
    let tc = createTestContext()
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
    let total = CurrencyConversionService.totalValue(
      for: snapshot, displayCurrency: "usd", exchangeRate: er)

    // 1000 USD + 31500/31.5 USD = 1000 + 1000 = 2000
    #expect(total == Decimal(2000))
  }

  // MARK: - Net Cash Flow Tests

  @Test("Net cash flow with different currencies")
  func testNetCashFlowConversion() throws {
    let tc = createTestContext()
    let snapshot = Snapshot(date: Date())
    tc.context.insert(snapshot)

    let cf1 = CashFlowOperation(cashFlowDescription: "USD Deposit", amount: Decimal(1000))
    cf1.currency = "usd"
    cf1.snapshot = snapshot
    tc.context.insert(cf1)

    let cf2 = CashFlowOperation(cashFlowDescription: "TWD Deposit", amount: Decimal(31500))
    cf2.currency = "twd"
    cf2.snapshot = snapshot
    tc.context.insert(cf2)

    let er = try makeExchangeRate(rates: ["twd": 31.5])
    let netCF = CurrencyConversionService.netCashFlow(
      for: snapshot, displayCurrency: "usd", exchangeRate: er)

    // 1000 USD + 31500/31.5 USD = 2000
    #expect(netCF == Decimal(2000))
  }

  // MARK: - Category Values Tests

  @Test("Category values grouping with conversion")
  func testCategoryValuesGrouping() throws {
    let tc = createTestContext()
    let snapshot = Snapshot(date: Date())
    tc.context.insert(snapshot)

    let category = Category(name: "Stocks")
    tc.context.insert(category)

    let assetUSD = Asset(name: "US Stock")
    assetUSD.currency = "usd"
    assetUSD.category = category
    tc.context.insert(assetUSD)

    let assetTWD = Asset(name: "TW Stock")
    assetTWD.currency = "twd"
    assetTWD.category = category
    tc.context.insert(assetTWD)

    let sav1 = SnapshotAssetValue(marketValue: Decimal(1000))
    sav1.snapshot = snapshot
    sav1.asset = assetUSD
    tc.context.insert(sav1)

    let sav2 = SnapshotAssetValue(marketValue: Decimal(31500))
    sav2.snapshot = snapshot
    sav2.asset = assetTWD
    tc.context.insert(sav2)

    let er = try makeExchangeRate(rates: ["twd": 31.5])
    let values = CurrencyConversionService.categoryValues(
      for: snapshot, displayCurrency: "usd", exchangeRate: er)

    #expect(values["Stocks"] == Decimal(2000))
  }

  // MARK: - canConvert Tests

  @Test("canConvert returns true when rates available")
  func testCanConvertAvailable() throws {
    let er = try makeExchangeRate(rates: ["twd": 31.5, "eur": 0.92])
    #expect(CurrencyConversionService.canConvert(from: "usd", to: "twd", using: er))
    #expect(CurrencyConversionService.canConvert(from: "eur", to: "twd", using: er))
  }

  @Test("canConvert returns false when rate missing")
  func testCanConvertMissing() throws {
    let er = try makeExchangeRate(rates: ["twd": 31.5])
    #expect(!CurrencyConversionService.canConvert(from: "usd", to: "gbp", using: er))
  }

  @Test("canConvert returns false with nil exchange rate")
  func testCanConvertNilExchangeRate() {
    #expect(!CurrencyConversionService.canConvert(from: "usd", to: "twd", using: nil))
  }
}
