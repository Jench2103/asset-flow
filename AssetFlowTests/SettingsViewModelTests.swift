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

  /// Creates an isolated SettingsService with pre-configured values
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
    // Arrange
    let settingsService = createSettingsService(mainCurrency: "EUR")

    // Act
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Assert
    #expect(viewModel.selectedCurrency == "EUR")
  }

  @Test("ViewModel loads existing goal as formatted string")
  func testLoadsExistingGoalAsFormattedString() {
    // Arrange
    let settingsService = createSettingsService(financialGoal: Decimal(75000))

    // Act
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Assert
    #expect(viewModel.goalAmountString == "75000")
  }

  @Test("ViewModel loads empty string when no goal set")
  func testLoadsEmptyStringWhenNoGoal() {
    // Arrange
    let settingsService = SettingsService.createForTesting()

    // Act
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Assert
    #expect(viewModel.goalAmountString.isEmpty)
  }

  // MARK: - Currency Selection

  @Test("Changing selected currency updates settings service immediately")
  func testCurrencyChangeUpdatesSettingsImmediately() {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act
    viewModel.selectedCurrency = "JPY"

    // Assert
    #expect(settingsService.mainCurrency == "JPY")
  }

  @Test("Available currencies come from CurrencyService")
  func testCurrenciesFromCurrencyService() {
    // Arrange
    let settingsService = SettingsService.createForTesting()

    // Act
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Assert
    #expect(viewModel.availableCurrencies.count == CurrencyService.shared.currencies.count)
    #expect(viewModel.availableCurrencies.contains { $0.code == "USD" })
  }

  // MARK: - Goal Validation

  @Test("Empty goal string is valid (no goal set)")
  func testEmptyGoalStringIsValid() {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act
    viewModel.goalAmountString = ""

    // Assert
    #expect(viewModel.goalValidationMessage == nil)
    #expect(viewModel.isSaveDisabled == false)
  }

  @Test("Positive number is valid goal")
  func testPositiveNumberIsValidGoal() {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act
    viewModel.goalAmountString = "100000"

    // Assert
    #expect(viewModel.goalValidationMessage == nil)
    #expect(viewModel.isSaveDisabled == false)
  }

  @Test("Zero is invalid goal")
  func testZeroIsInvalidGoal() {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act
    viewModel.goalAmountString = "0"

    // Assert
    #expect(viewModel.goalValidationMessage != nil)
    #expect(viewModel.isSaveDisabled == true)
  }

  @Test("Negative number is invalid goal")
  func testNegativeNumberIsInvalidGoal() {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act
    viewModel.goalAmountString = "-5000"

    // Assert
    #expect(viewModel.goalValidationMessage != nil)
    #expect(viewModel.isSaveDisabled == true)
  }

  @Test("Non-numeric string is invalid goal")
  func testNonNumericStringIsInvalidGoal() {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act
    viewModel.goalAmountString = "abc"

    // Assert
    #expect(viewModel.goalValidationMessage != nil)
    #expect(viewModel.isSaveDisabled == true)
  }

  @Test("Whitespace-only string is treated as empty (valid)")
  func testWhitespaceOnlyIsValid() {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act
    viewModel.goalAmountString = "   "

    // Assert
    #expect(viewModel.goalValidationMessage == nil)
    #expect(viewModel.isSaveDisabled == false)
  }

  // MARK: - User Interaction

  @Test("hasUserInteracted is false on init")
  func testHasUserInteractedFalseOnInit() {
    // Arrange
    let settingsService = SettingsService.createForTesting()

    // Act
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Assert
    #expect(viewModel.hasUserInteracted == false)
  }

  @Test("hasUserInteracted becomes true when goal changes")
  func testHasUserInteractedTrueAfterGoalChange() {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act
    viewModel.goalAmountString = "50000"

    // Assert
    #expect(viewModel.hasUserInteracted == true)
  }

  @Test("Same value does not set hasUserInteracted")
  func testSameValueDoesNotSetInteracted() {
    // Arrange
    let settingsService = createSettingsService(financialGoal: Decimal(50000))
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act - set to same value
    viewModel.goalAmountString = "50000"

    // Assert
    #expect(viewModel.hasUserInteracted == false)
  }

  // MARK: - Auto-Save and Commit Actions

  @Test("commitGoal persists valid goal to settings service")
  func testCommitGoalPersistsToService() {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "75000"

    // Act
    viewModel.commitGoal()

    // Assert
    #expect(settingsService.financialGoal == Decimal(75000))
  }

  @Test("commitGoal with empty string sets goal to nil")
  func testCommitEmptyGoalSetsNil() {
    // Arrange
    let settingsService = createSettingsService(financialGoal: Decimal(100000))
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = ""

    // Act
    viewModel.commitGoal()

    // Assert
    #expect(settingsService.financialGoal == nil)
  }

  @Test("clearGoal sets goal to nil and clears input")
  func testClearGoalSetsNilAndClearsInput() {
    // Arrange
    let settingsService = createSettingsService(financialGoal: Decimal(50000))
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act
    viewModel.clearGoal()

    // Assert
    #expect(viewModel.goalAmountString.isEmpty)
    #expect(settingsService.financialGoal == nil)
  }

  @Test("commitGoal resets hasUserInteracted")
  func testCommitGoalResetsHasUserInteracted() {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "50000"
    #expect(viewModel.hasUserInteracted == true)

    // Act
    viewModel.commitGoal()

    // Assert
    #expect(viewModel.hasUserInteracted == false)
  }

  @Test("Invalid goal does not trigger auto-save")
  func testInvalidGoalDoesNotAutoSave() async throws {
    // Arrange
    let settingsService = createSettingsService(financialGoal: Decimal(50000))
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act - set invalid goal
    viewModel.goalAmountString = "-100"

    // Wait for debounce period to pass
    try await Task.sleep(for: .seconds(1))

    // Assert - original goal should remain unchanged
    #expect(settingsService.financialGoal == Decimal(50000))
    #expect(viewModel.showSavedIndicator == false)
  }

  @Test("commitGoal saves immediately without debounce")
  func testCommitGoalSavesImmediately() {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "100000"

    // Act - commit immediately (simulates Enter key)
    viewModel.commitGoal()

    // Assert - saved immediately, no waiting for debounce
    #expect(settingsService.financialGoal == Decimal(100000))
    #expect(viewModel.showSavedIndicator == true)
  }

  @Test("onFocusLost saves immediately if valid")
  func testOnFocusLostSavesImmediately() {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "200000"

    // Act - focus lost (simulates clicking away)
    viewModel.onFocusLost()

    // Assert - saved immediately
    #expect(settingsService.financialGoal == Decimal(200000))
    #expect(viewModel.showSavedIndicator == true)
  }

  @Test("onFocusLost does not save if invalid")
  func testOnFocusLostDoesNotSaveIfInvalid() {
    // Arrange
    let settingsService = createSettingsService(financialGoal: Decimal(50000))
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "abc"

    // Act - focus lost with invalid input
    viewModel.onFocusLost()

    // Assert - original goal unchanged
    #expect(settingsService.financialGoal == Decimal(50000))
    #expect(viewModel.showSavedIndicator == false)
  }

  @Test("clearGoal saves nil immediately and shows indicator")
  func testClearGoalSavesNilAndShowsIndicator() {
    // Arrange
    let settingsService = createSettingsService(financialGoal: Decimal(50000))
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act
    viewModel.clearGoal()

    // Assert
    #expect(viewModel.goalAmountString.isEmpty)
    #expect(settingsService.financialGoal == nil)
    #expect(viewModel.showSavedIndicator == true)
  }

  @Test("showSavedIndicator becomes true after save")
  func testSavedIndicatorShowsAfterSave() {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "75000"

    // Act
    viewModel.commitGoal()

    // Assert
    #expect(viewModel.showSavedIndicator == true)
  }

  @Test("showSavedIndicator becomes false after delay")
  func testSavedIndicatorHidesAfterDelay() async throws {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)
    viewModel.goalAmountString = "75000"

    // Act
    viewModel.commitGoal()
    #expect(viewModel.showSavedIndicator == true)

    // Wait for indicator to auto-hide (1.5 seconds + buffer)
    try await Task.sleep(for: .seconds(2))

    // Assert
    #expect(viewModel.showSavedIndicator == false)
  }

  @Test("Goal auto-saves after debounce delay when valid")
  func testGoalAutoSavesAfterDebounce() async throws {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act - type valid goal
    viewModel.goalAmountString = "150000"

    // Wait for debounce period (0.75s) plus buffer
    try await Task.sleep(for: .seconds(1))

    // Assert - should have auto-saved
    #expect(settingsService.financialGoal == Decimal(150000))
    #expect(viewModel.showSavedIndicator == true)
  }

  @Test("Rapid typing cancels previous debounce")
  func testTypingCancelsPreviousDebounce() async throws {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act - simulate rapid typing
    viewModel.goalAmountString = "1"
    try await Task.sleep(for: .milliseconds(200))
    viewModel.goalAmountString = "12"
    try await Task.sleep(for: .milliseconds(200))
    viewModel.goalAmountString = "123"
    try await Task.sleep(for: .milliseconds(200))
    viewModel.goalAmountString = "1234"

    // At this point, no save should have occurred yet
    #expect(settingsService.financialGoal == nil)

    // Wait for debounce to complete
    try await Task.sleep(for: .seconds(1))

    // Assert - only final value should be saved
    #expect(settingsService.financialGoal == Decimal(1234))
  }

  // MARK: - Issue 1: Init with Existing Goal Should Not Show Saved Indicator

  @Test("Init with existing goal does not show saved indicator")
  func testInitWithGoalDoesNotShowSavedIndicator() async throws {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    settingsService.financialGoal = Decimal(500000)

    // Act
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Wait for any debounced save to complete
    try await Task.sleep(for: .seconds(1))

    // Assert - saved indicator should NOT appear from init
    #expect(viewModel.showSavedIndicator == false)
  }

  @Test("Init with existing goal does not trigger debounced save")
  func testInitDoesNotTriggerDebouncedSave() async throws {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let originalGoal = Decimal(500000)
    settingsService.financialGoal = originalGoal

    // Act
    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Modify goal in service directly (simulating external change)
    settingsService.financialGoal = Decimal(999999)

    // Wait for any debounced save
    try await Task.sleep(for: .seconds(1))

    // Assert - ViewModel should NOT have overwritten the external change
    #expect(settingsService.financialGoal == Decimal(999999))
    // Suppress unused variable warning
    _ = viewModel.goalAmountString
  }

  // MARK: - Issue 2: Currency Change Converts Financial Goal

  @Test("Currency change converts financial goal to rounded integer")
  func testCurrencyChangeConvertsGoal() async throws {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    let exchangeRateService = ExchangeRateService.shared
    settingsService.financialGoal = Decimal(1000)
    settingsService.mainCurrency = "USD"

    let viewModel = SettingsViewModel(
      settingsService: settingsService,
      exchangeRateService: exchangeRateService
    )

    // Ensure rates are loaded
    await exchangeRateService.fetchRates()

    // Act - change to EUR
    viewModel.selectedCurrency = "EUR"

    // Wait for async conversion
    try await Task.sleep(for: .milliseconds(500))

    // Assert - goal should be converted (not exactly 1000 anymore)
    let goal = try #require(settingsService.financialGoal)
    #expect(goal != Decimal(1000))

    // Assert - goal should be rounded to integer (no decimal places)
    let goalAsDouble = NSDecimalNumber(decimal: goal).doubleValue
    #expect(goalAsDouble == goalAsDouble.rounded())
  }

  @Test("Currency change with no goal does nothing")
  func testCurrencyChangeWithNoGoalDoesNothing() async throws {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    settingsService.financialGoal = nil

    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act
    viewModel.selectedCurrency = "EUR"

    // Wait for any async work
    try await Task.sleep(for: .milliseconds(500))

    // Assert
    #expect(settingsService.financialGoal == nil)
  }

  @Test("Currency change shows conversion message")
  func testCurrencyChangeShowsConversionMessage() async throws {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    settingsService.financialGoal = Decimal(1000)
    settingsService.mainCurrency = "USD"

    let viewModel = SettingsViewModel(settingsService: settingsService)
    await ExchangeRateService.shared.fetchRates()

    // Act
    viewModel.selectedCurrency = "EUR"

    // Wait for async conversion
    try await Task.sleep(for: .milliseconds(500))

    // Assert
    #expect(viewModel.conversionMessage != nil)
  }

  @Test("Same currency selection does not trigger conversion")
  func testSameCurrencyDoesNotTriggerConversion() async throws {
    // Arrange
    let settingsService = SettingsService.createForTesting()
    settingsService.financialGoal = Decimal(1000)
    settingsService.mainCurrency = "USD"

    let viewModel = SettingsViewModel(settingsService: settingsService)

    // Act - set same currency
    viewModel.selectedCurrency = "USD"

    // Wait for any async work
    try await Task.sleep(for: .milliseconds(500))

    // Assert - goal should remain unchanged
    #expect(settingsService.financialGoal == Decimal(1000))
    #expect(viewModel.conversionMessage == nil)
  }
}
