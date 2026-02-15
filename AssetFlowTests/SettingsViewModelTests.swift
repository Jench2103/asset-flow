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

  // MARK: - Date Format

  @Test("Init loads current dateFormat from service")
  func testInitLoadsDateFormat() {
    let settingsService = SettingsService.createForTesting()
    settingsService.dateFormat = .long
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(viewModel.selectedDateFormat == .long)
  }

  @Test("Changing dateFormat updates service immediately")
  func testDateFormatChangeUpdatesService() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.selectedDateFormat = .complete
    #expect(settingsService.dateFormat == .complete)
  }

  @Test("Same dateFormat doesn't trigger update")
  func testSameDateFormatDoesNotTriggerUpdate() {
    let settingsService = SettingsService.createForTesting()
    settingsService.dateFormat = .abbreviated
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.selectedDateFormat = .abbreviated
    #expect(settingsService.dateFormat == .abbreviated)
  }

  @Test("Available formats has 4 items")
  func testAvailableFormatsCount() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(viewModel.availableDateFormats.count == 4)
  }

  // MARK: - Default Platform

  @Test("Init loads current defaultPlatform from service")
  func testInitLoadsDefaultPlatform() {
    let settingsService = SettingsService.createForTesting()
    settingsService.defaultPlatform = "Schwab"
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(viewModel.defaultPlatformString == "Schwab")
  }

  @Test("Changing defaultPlatform updates service immediately")
  func testDefaultPlatformChangeUpdatesService() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.defaultPlatformString = "Firstrade"
    #expect(settingsService.defaultPlatform == "Firstrade")
  }

  @Test("Empty defaultPlatform is valid")
  func testEmptyDefaultPlatformIsValid() {
    let settingsService = SettingsService.createForTesting()
    settingsService.defaultPlatform = "Schwab"
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.defaultPlatformString = ""
    #expect(settingsService.defaultPlatform == "")
  }

  @Test("Same defaultPlatform doesn't trigger update")
  func testSameDefaultPlatformDoesNotTriggerUpdate() {
    let settingsService = SettingsService.createForTesting()
    settingsService.defaultPlatform = "Schwab"
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.defaultPlatformString = "Schwab"
    #expect(settingsService.defaultPlatform == "Schwab")
  }
}
