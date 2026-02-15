//
//  SettingsViewModelTests.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/28.
//

import Foundation
import Testing

@testable import AssetFlow

@Suite("SettingsViewModel Tests")
@MainActor
struct SettingsViewModelTests {

  // MARK: - Initialization

  @Test("ViewModel initializes with current settings values")
  func testInitializesWithCurrentSettings() {
    let settingsService = SettingsService.createForTesting()
    settingsService.mainCurrency = "EUR"
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(viewModel.selectedCurrency == "EUR")
  }

  // MARK: - Currency Selection

  @Test("Changing selected currency updates settings service immediately")
  func testCurrencyChangeUpdatesSettingsImmediately() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.selectedCurrency = "JPY"
    #expect(settingsService.mainCurrency == "JPY")
  }

  @Test("Available currencies come from CurrencyService")
  func testCurrenciesFromCurrencyService() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(viewModel.availableCurrencies.count == CurrencyService.shared.currencies.count)
    #expect(viewModel.availableCurrencies.contains { $0.code == "USD" })
  }

  @Test("Same currency selection does not update service")
  func testSameCurrencyDoesNotUpdateService() {
    let settingsService = SettingsService.createForTesting()
    settingsService.mainCurrency = "USD"
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.selectedCurrency = "USD"
    #expect(settingsService.mainCurrency == "USD")
  }
}
