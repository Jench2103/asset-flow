//
//  ExchangeRateServiceTests.swift
//  AssetFlowTests
//
//  Created by Claude on 2025/10/27.
//

import Foundation
import Testing

@testable import AssetFlow

@Suite("ExchangeRateService Static Convert Tests")
struct ExchangeRateServiceTests {

  /// Sample rates relative to USD base currency
  private let sampleRates: [String: Decimal] = [
    "USD": 1,
    "EUR": Decimal(string: "0.85")!,
    "JPY": 110,
    "GBP": Decimal(string: "0.73")!,
  ]

  private let baseCurrency = "USD"

  // MARK: - Same Currency

  @Test("Same currency returns original amount")
  func testSameCurrencyNoConversion() {
    let result = ExchangeRateService.convert(
      amount: 100, from: "USD", to: "USD",
      using: sampleRates, baseCurrency: baseCurrency)

    #expect(result == 100)
  }

  @Test("Same non-base currency returns original amount")
  func testSameNonBaseCurrencyNoConversion() {
    let result = ExchangeRateService.convert(
      amount: 50, from: "EUR", to: "EUR",
      using: sampleRates, baseCurrency: baseCurrency)

    #expect(result == 50)
  }

  // MARK: - Direct Conversion (from base currency)

  @Test("Convert from base currency to target uses rate directly")
  func testConvertFromBaseCurrency() {
    // 100 USD * 0.85 = 85 EUR
    let result = ExchangeRateService.convert(
      amount: 100, from: "USD", to: "EUR",
      using: sampleRates, baseCurrency: baseCurrency)

    #expect(result == Decimal(string: "85")!)
  }

  @Test("Convert from base currency to JPY")
  func testConvertFromBaseCurrencyToJPY() {
    // 100 USD * 110 = 11000 JPY
    let result = ExchangeRateService.convert(
      amount: 100, from: "USD", to: "JPY",
      using: sampleRates, baseCurrency: baseCurrency)

    #expect(result == 11000)
  }

  // MARK: - Inverse Conversion (to base currency)

  @Test("Convert to base currency divides by rate")
  func testConvertToBaseCurrency() {
    // 85 EUR / 0.85 = 100 USD
    let result = ExchangeRateService.convert(
      amount: 85, from: "EUR", to: "USD",
      using: sampleRates, baseCurrency: baseCurrency)

    #expect(result == 100)
  }

  @Test("Convert JPY to base currency")
  func testConvertJPYToBaseCurrency() {
    // 11000 JPY / 110 = 100 USD
    let result = ExchangeRateService.convert(
      amount: 11000, from: "JPY", to: "USD",
      using: sampleRates, baseCurrency: baseCurrency)

    #expect(result == 100)
  }

  // MARK: - Cross-Currency Conversion

  @Test("Convert between two non-base currencies via base")
  func testCrossCurrencyConversion() {
    // 100 EUR -> USD -> GBP
    // 100 / 0.85 (EUR->USD) * 0.73 (USD->GBP)
    let result = ExchangeRateService.convert(
      amount: 100, from: "EUR", to: "GBP",
      using: sampleRates, baseCurrency: baseCurrency)

    // 100 / 0.85 = 117.647... * 0.73 = 85.882...
    let expected = (Decimal(100) / Decimal(string: "0.85")!) * Decimal(string: "0.73")!
    #expect(result == expected)
  }

  // MARK: - Missing Rate Handling

  @Test("Missing target rate returns original amount")
  func testMissingTargetRateReturnsOriginal() {
    let result = ExchangeRateService.convert(
      amount: 100, from: "USD", to: "CHF",
      using: sampleRates, baseCurrency: baseCurrency)

    #expect(result == 100)
  }

  @Test("Missing source rate returns original amount")
  func testMissingSourceRateReturnsOriginal() {
    let result = ExchangeRateService.convert(
      amount: 100, from: "CHF", to: "USD",
      using: sampleRates, baseCurrency: baseCurrency)

    #expect(result == 100)
  }

  @Test("Missing both rates for cross-currency returns original amount")
  func testMissingBothRatesReturnsOriginal() {
    let result = ExchangeRateService.convert(
      amount: 100, from: "CHF", to: "SEK",
      using: sampleRates, baseCurrency: baseCurrency)

    #expect(result == 100)
  }

  // MARK: - Edge Cases

  @Test("Zero amount returns zero")
  func testZeroAmountReturnsZero() {
    let result = ExchangeRateService.convert(
      amount: 0, from: "USD", to: "EUR",
      using: sampleRates, baseCurrency: baseCurrency)

    #expect(result == 0)
  }

  @Test("Empty rates dictionary returns original amount")
  func testEmptyRatesReturnsOriginal() {
    let result = ExchangeRateService.convert(
      amount: 100, from: "USD", to: "EUR",
      using: [:], baseCurrency: baseCurrency)

    #expect(result == 100)
  }

  @Test("Zero rate for source currency returns original amount")
  func testZeroSourceRateReturnsOriginal() {
    let zeroRates: [String: Decimal] = ["EUR": 0, "GBP": Decimal(string: "0.73")!]
    let result = ExchangeRateService.convert(
      amount: 100, from: "EUR", to: "USD",
      using: zeroRates, baseCurrency: baseCurrency)

    #expect(result == 100)
  }
}
