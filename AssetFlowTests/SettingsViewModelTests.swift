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

  // MARK: - Test Setup Helpers

  private func createSettingsService(
    mainCurrency: String? = nil, financialGoal: Decimal? = nil
  ) -> SettingsService {
    let service = SettingsService.createForTesting()
    if let currency = mainCurrency {
      service.mainCurrency = currency
    }
    if let goal = financialGoal {
      service.financialGoal = goal
    }
    return service
  }

  // MARK: - Initialization

  @Test("ViewModel initializes with current settings values")
  func testInitializesWithCurrentSettings() {
    let settingsService = createSettingsService(mainCurrency: "EUR")
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(viewModel.selectedCurrency == "EUR")
  }

  @Test("ViewModel loads existing goal as formatted string")
  func testLoadsExistingGoalAsFormattedString() {
    let settingsService = createSettingsService(financialGoal: Decimal(75000))
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(viewModel.goalAmountString == "75000")
  }

  @Test("ViewModel loads empty string when no goal set")
  func testLoadsEmptyStringWhenNoGoal() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(viewModel.goalAmountString.isEmpty)
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

  // MARK: - Goal Validation

  @Test("Empty goal string is valid (no goal set)")
  func testEmptyGoalStringIsValid() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = ""
    #expect(viewModel.goalValidationMessage == nil)
    #expect(viewModel.isSaveDisabled == false)
  }

  @Test("Positive number is valid goal")
  func testPositiveNumberIsValidGoal() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "100000"
    #expect(viewModel.goalValidationMessage == nil)
    #expect(viewModel.isSaveDisabled == false)
  }

  @Test("Zero is invalid goal")
  func testZeroIsInvalidGoal() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "0"
    #expect(viewModel.goalValidationMessage != nil)
    #expect(viewModel.isSaveDisabled == true)
  }

  @Test("Negative number is invalid goal")
  func testNegativeNumberIsInvalidGoal() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "-5000"
    #expect(viewModel.goalValidationMessage != nil)
    #expect(viewModel.isSaveDisabled == true)
  }

  @Test("Non-numeric string is invalid goal")
  func testNonNumericStringIsInvalidGoal() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "abc"
    #expect(viewModel.goalValidationMessage != nil)
    #expect(viewModel.isSaveDisabled == true)
  }

  @Test("Whitespace-only string is treated as empty (valid)")
  func testWhitespaceOnlyIsValid() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "   "
    #expect(viewModel.goalValidationMessage == nil)
    #expect(viewModel.isSaveDisabled == false)
  }

  // MARK: - User Interaction

  @Test("hasUserInteracted is false on init")
  func testHasUserInteractedFalseOnInit() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    #expect(viewModel.hasUserInteracted == false)
  }

  @Test("hasUserInteracted becomes true when goal changes")
  func testHasUserInteractedTrueAfterGoalChange() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "50000"
    #expect(viewModel.hasUserInteracted == true)
  }

  @Test("Same value does not set hasUserInteracted")
  func testSameValueDoesNotSetInteracted() {
    let settingsService = createSettingsService(financialGoal: Decimal(50000))
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "50000"
    #expect(viewModel.hasUserInteracted == false)
  }

  // MARK: - Auto-Save and Commit Actions

  @Test("commitGoal persists valid goal to settings service")
  func testCommitGoalPersistsToService() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "75000"
    viewModel.commitGoal()
    #expect(settingsService.financialGoal == Decimal(75000))
  }

  @Test("commitGoal with empty string sets goal to nil")
  func testCommitEmptyGoalSetsNil() {
    let settingsService = createSettingsService(financialGoal: Decimal(100000))
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = ""
    viewModel.commitGoal()
    #expect(settingsService.financialGoal == nil)
  }

  @Test("clearGoal sets goal to nil and clears input")
  func testClearGoalSetsNilAndClearsInput() {
    let settingsService = createSettingsService(financialGoal: Decimal(50000))
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.clearGoal()
    #expect(viewModel.goalAmountString.isEmpty)
    #expect(settingsService.financialGoal == nil)
  }

  @Test("commitGoal resets hasUserInteracted")
  func testCommitGoalResetsHasUserInteracted() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "50000"
    #expect(viewModel.hasUserInteracted == true)
    viewModel.commitGoal()
    #expect(viewModel.hasUserInteracted == false)
  }

  @Test("Invalid goal does not trigger auto-save")
  func testInvalidGoalDoesNotAutoSave() async throws {
    let settingsService = createSettingsService(financialGoal: Decimal(50000))
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "-100"
    try await Task.sleep(for: .seconds(1))
    #expect(settingsService.financialGoal == Decimal(50000))
    #expect(viewModel.showSavedIndicator == false)
  }

  @Test("commitGoal saves immediately without debounce")
  func testCommitGoalSavesImmediately() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "100000"
    viewModel.commitGoal()
    #expect(settingsService.financialGoal == Decimal(100000))
    #expect(viewModel.showSavedIndicator == true)
  }

  @Test("onFocusLost saves immediately if valid")
  func testOnFocusLostSavesImmediately() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "200000"
    viewModel.onFocusLost()
    #expect(settingsService.financialGoal == Decimal(200000))
    #expect(viewModel.showSavedIndicator == true)
  }

  @Test("onFocusLost does not save if invalid")
  func testOnFocusLostDoesNotSaveIfInvalid() {
    let settingsService = createSettingsService(financialGoal: Decimal(50000))
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "abc"
    viewModel.onFocusLost()
    #expect(settingsService.financialGoal == Decimal(50000))
    #expect(viewModel.showSavedIndicator == false)
  }

  @Test("clearGoal saves nil immediately and shows indicator")
  func testClearGoalSavesNilAndShowsIndicator() {
    let settingsService = createSettingsService(financialGoal: Decimal(50000))
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.clearGoal()
    #expect(viewModel.goalAmountString.isEmpty)
    #expect(settingsService.financialGoal == nil)
    #expect(viewModel.showSavedIndicator == true)
  }

  @Test("showSavedIndicator becomes true after save")
  func testSavedIndicatorShowsAfterSave() {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "75000"
    viewModel.commitGoal()
    #expect(viewModel.showSavedIndicator == true)
  }

  @Test("showSavedIndicator becomes false after delay")
  func testSavedIndicatorHidesAfterDelay() async throws {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "75000"
    viewModel.commitGoal()
    #expect(viewModel.showSavedIndicator == true)
    try await Task.sleep(for: .seconds(2))
    #expect(viewModel.showSavedIndicator == false)
  }

  @Test("Goal auto-saves after debounce delay when valid")
  func testGoalAutoSavesAfterDebounce() async throws {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "150000"
    try await Task.sleep(for: .seconds(1))
    #expect(settingsService.financialGoal == Decimal(150000))
    #expect(viewModel.showSavedIndicator == true)
  }

  @Test("Rapid typing cancels previous debounce")
  func testTypingCancelsPreviousDebounce() async throws {
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "1"
    try await Task.sleep(for: .milliseconds(200))
    viewModel.goalAmountString = "12"
    try await Task.sleep(for: .milliseconds(200))
    viewModel.goalAmountString = "123"
    try await Task.sleep(for: .milliseconds(200))
    viewModel.goalAmountString = "1234"
    #expect(settingsService.financialGoal == nil)
    try await Task.sleep(for: .seconds(1))
    #expect(settingsService.financialGoal == Decimal(1234))
  }

  @Test("Init with existing goal does not show saved indicator")
  func testInitWithGoalDoesNotShowSavedIndicator() async throws {
    let settingsService = SettingsService.createForTesting()
    settingsService.financialGoal = Decimal(500000)
    let viewModel = SettingsViewModel(settingsService: settingsService)
    try await Task.sleep(for: .seconds(1))
    #expect(viewModel.showSavedIndicator == false)
  }

  @Test("Init with existing goal does not trigger debounced save")
  func testInitDoesNotTriggerDebouncedSave() async throws {
    let settingsService = SettingsService.createForTesting()
    settingsService.financialGoal = Decimal(500000)
    let viewModel = SettingsViewModel(settingsService: settingsService)
    settingsService.financialGoal = Decimal(999999)
    try await Task.sleep(for: .seconds(1))
    #expect(settingsService.financialGoal == Decimal(999999))
    _ = viewModel.goalAmountString
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
