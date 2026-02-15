//
//  SettingsServiceTests.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/28.
//

import Foundation
import Testing

@testable import AssetFlow

@Suite("SettingsService Tests")
@MainActor
struct SettingsServiceTests {

  // MARK: - Default Values

  @Test("Default main currency is USD when storage is empty")
  func testDefaultMainCurrencyIsUSD() {
    let service = SettingsService.createForTesting()
    #expect(service.mainCurrency == "USD")
  }

  // MARK: - Main Currency Persistence

  @Test("Setting main currency persists the value")
  func testMainCurrencyPersists() {
    let service = SettingsService.createForTesting()
    service.mainCurrency = "EUR"
    #expect(service.mainCurrency == "EUR")
  }

  @Test("Main currency changes are observable")
  func testMainCurrencyChangesAreObservable() {
    let service = SettingsService.createForTesting()
    service.mainCurrency = "JPY"
    service.mainCurrency = "GBP"
    #expect(service.mainCurrency == "GBP")
  }

  // MARK: - Test Isolation

  @Test("Each test instance has isolated storage")
  func testIsolatedStorage() {
    let service1 = SettingsService.createForTesting()
    let service2 = SettingsService.createForTesting()

    service1.mainCurrency = "EUR"

    #expect(service2.mainCurrency == "USD")
  }
}
