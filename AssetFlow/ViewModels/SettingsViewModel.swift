//
//  SettingsViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/28.
//

import Foundation

/// ViewModel for the Settings screen
///
/// Manages form state for settings including:
/// - Main currency selection (saved immediately)
/// - Financial goal input (auto-saved with debounce)
///
/// Auto-save behavior:
/// - Changes auto-save after 0.75s debounce when input is valid
/// - Invalid input shows validation but doesn't save
/// - Enter key or focus loss triggers immediate save
/// - Visual "Saved" indicator appears for 1.5s after save
///
/// Currency change behavior:
/// - When currency changes, financial goal is converted using exchange rates
/// - Conversion message shown briefly after successful conversion
@Observable
@MainActor
final class SettingsViewModel {
  /// The settings service for persistence
  private let settingsService: SettingsService

  /// The exchange rate service for currency conversion
  private let exchangeRateService: ExchangeRateService

  /// Track previous currency for conversion
  private var previousCurrency: String

  /// Flag to suppress didSet during currency conversion
  private var isConvertingGoal = false

  /// Selected currency code
  var selectedCurrency: String {
    didSet {
      guard selectedCurrency != oldValue else { return }
      let fromCurrency = previousCurrency
      previousCurrency = selectedCurrency
      settingsService.mainCurrency = selectedCurrency

      // Convert goal if exists
      Task {
        await convertGoal(from: fromCurrency, to: selectedCurrency)
      }
    }
  }

  /// Financial goal amount as string for text field binding
  var goalAmountString: String = "" {
    didSet {
      guard goalAmountString != oldValue else { return }
      guard !isConvertingGoal else { return }
      hasUserInteracted = true
      validateGoal()
      scheduleDebouncedSave()
    }
  }

  /// Validation message for goal input
  var goalValidationMessage: String?

  /// Whether the user has interacted with the form
  var hasUserInteracted = false

  /// Shows brief "Saved" indicator after successful save
  var showSavedIndicator: Bool = false

  /// Message showing conversion info (e.g., "Converted from USD 1,000,000")
  var conversionMessage: String?

  /// Task handle for debounced save (cancellable)
  private var saveTask: Task<Void, Never>?

  /// Task handle for hiding the saved indicator
  private var indicatorTask: Task<Void, Never>?

  /// Task handle for hiding the conversion message
  private var conversionMessageTask: Task<Void, Never>?

  /// Debounce delay in nanoseconds (0.75 seconds)
  private let debounceDelay: UInt64 = 750_000_000

  /// Indicator display duration in nanoseconds (1.5 seconds)
  private let indicatorDuration: UInt64 = 1_500_000_000

  /// Conversion message display duration in nanoseconds (3 seconds)
  private let conversionMessageDuration: UInt64 = 3_000_000_000

  /// Available currencies for picker
  var availableCurrencies: [Currency] {
    CurrencyService.shared.currencies
  }

  /// Whether the save button should be disabled (also used for validation status)
  var isSaveDisabled: Bool {
    goalValidationMessage != nil
  }

  init(
    settingsService: SettingsService? = nil,
    exchangeRateService: ExchangeRateService? = nil
  ) {
    let resolvedSettingsService = settingsService ?? SettingsService.shared
    self.settingsService = resolvedSettingsService
    self.exchangeRateService = exchangeRateService ?? ExchangeRateService.shared
    self.selectedCurrency = resolvedSettingsService.mainCurrency
    self.previousCurrency = resolvedSettingsService.mainCurrency

    // Load existing goal as string
    if let goal = resolvedSettingsService.financialGoal {
      self.goalAmountString = NSDecimalNumber(decimal: goal).stringValue
    }

    // Reset interaction flag after loading initial values
    // (property observers may have been triggered during init)
    hasUserInteracted = false

    // Cancel any save scheduled during init to prevent spurious "Saved" indicator
    saveTask?.cancel()
  }

  // MARK: - Validation

  private func validateGoal() {
    let trimmed = goalAmountString.trimmingCharacters(in: .whitespaces)

    // Empty string is valid (no goal set)
    if trimmed.isEmpty {
      goalValidationMessage = nil
      return
    }

    // Must be a valid number
    guard let value = Decimal(string: trimmed) else {
      goalValidationMessage = String(
        localized: "Financial goal must be a valid number.", table: "Services")
      return
    }

    // Must be positive
    if value <= 0 {
      goalValidationMessage = String(
        localized: "Financial goal must be greater than zero.", table: "Services")
      return
    }

    goalValidationMessage = nil
  }

  // MARK: - Auto-Save Logic

  /// Schedule debounced auto-save (cancels previous pending save)
  private func scheduleDebouncedSave() {
    // Cancel any pending save
    saveTask?.cancel()

    // Don't schedule if invalid
    guard goalValidationMessage == nil else { return }

    // Schedule new save after debounce delay
    saveTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: self?.debounceDelay ?? 750_000_000)
        self?.performSave()
      } catch {
        // Task was cancelled - do nothing
      }
    }
  }

  /// Perform actual save and show feedback
  private func performSave() {
    // Don't save if invalid
    guard goalValidationMessage == nil else { return }

    let trimmed = goalAmountString.trimmingCharacters(in: .whitespaces)

    if trimmed.isEmpty {
      settingsService.financialGoal = nil
    } else if let value = Decimal(string: trimmed) {
      settingsService.financialGoal = value
    }

    hasUserInteracted = false
    showSavedIndicatorWithAutoHide()
  }

  /// Show saved indicator and schedule auto-hide
  private func showSavedIndicatorWithAutoHide() {
    // Cancel any pending hide
    indicatorTask?.cancel()

    showSavedIndicator = true

    // Schedule auto-hide
    indicatorTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: self?.indicatorDuration ?? 1_500_000_000)
        self?.showSavedIndicator = false
      } catch {
        // Task was cancelled - do nothing
      }
    }
  }

  // MARK: - Actions

  /// Immediate save on Enter key press (bypasses debounce)
  func commitGoal() {
    saveTask?.cancel()
    performSave()
  }

  /// Immediate save on field blur/focus loss
  func onFocusLost() {
    saveTask?.cancel()
    // Only save if valid
    guard goalValidationMessage == nil else { return }
    performSave()
  }

  /// Clears the financial goal and saves immediately
  func clearGoal() {
    saveTask?.cancel()
    goalAmountString = ""
    settingsService.financialGoal = nil
    hasUserInteracted = false
    showSavedIndicatorWithAutoHide()
  }

  // MARK: - Currency Conversion

  /// Convert financial goal when currency changes
  private func convertGoal(from oldCurrency: String, to newCurrency: String) async {
    guard let currentGoal = settingsService.financialGoal else { return }

    // Ensure rates are fetched
    await exchangeRateService.fetchRates()

    // Convert using exchange rate service
    var convertedGoal = exchangeRateService.convert(
      amount: currentGoal,
      from: oldCurrency,
      to: newCurrency
    )

    // Round to integer (no decimal places for financial goal)
    var roundedGoal = Decimal()
    NSDecimalRound(&roundedGoal, &convertedGoal, 0, .plain)

    // Update goal (suppress didSet save trigger)
    isConvertingGoal = true
    goalAmountString = NSDecimalNumber(decimal: roundedGoal).stringValue
    settingsService.financialGoal = roundedGoal
    isConvertingGoal = false

    // Show conversion message
    showConversionMessage(originalAmount: currentGoal, originalCurrency: oldCurrency)
  }

  /// Show conversion message with auto-hide
  private func showConversionMessage(originalAmount: Decimal, originalCurrency: String) {
    let formatted = originalAmount.formatted(currency: originalCurrency)
    conversionMessage = String(
      localized: "Converted from \(formatted)",
      table: "Services"
    )

    // Cancel any pending hide
    conversionMessageTask?.cancel()

    // Schedule auto-hide
    conversionMessageTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: self?.conversionMessageDuration ?? 3_000_000_000)
        self?.conversionMessage = nil
      } catch {
        // Task was cancelled - do nothing
      }
    }
  }
}
