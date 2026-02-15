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
@Observable
@MainActor
final class SettingsViewModel {
  /// The settings service for persistence
  private let settingsService: SettingsService

  /// Selected currency code
  var selectedCurrency: String {
    didSet {
      guard selectedCurrency != oldValue else { return }
      settingsService.mainCurrency = selectedCurrency
    }
  }

  /// Financial goal amount as string for text field binding
  var goalAmountString: String = "" {
    didSet {
      guard goalAmountString != oldValue else { return }
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

  /// Task handle for debounced save (cancellable)
  private var saveTask: Task<Void, Never>?

  /// Task handle for hiding the saved indicator
  private var indicatorTask: Task<Void, Never>?

  /// Debounce delay in nanoseconds (0.75 seconds)
  private let debounceDelay: UInt64 = 750_000_000

  /// Indicator display duration in nanoseconds (1.5 seconds)
  private let indicatorDuration: UInt64 = 1_500_000_000

  /// Available currencies for picker
  var availableCurrencies: [Currency] {
    CurrencyService.shared.currencies
  }

  /// Whether the save button should be disabled (also used for validation status)
  var isSaveDisabled: Bool {
    goalValidationMessage != nil
  }

  init(settingsService: SettingsService? = nil) {
    let resolvedSettingsService = settingsService ?? SettingsService.shared
    self.settingsService = resolvedSettingsService
    self.selectedCurrency = resolvedSettingsService.mainCurrency

    // Load existing goal as string
    if let goal = resolvedSettingsService.financialGoal {
      self.goalAmountString = NSDecimalNumber(decimal: goal).stringValue
    }

    // Reset interaction flag after loading initial values
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
    saveTask?.cancel()

    guard goalValidationMessage == nil else { return }

    saveTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: self?.debounceDelay ?? 750_000_000)
        self?.performSave()
      } catch {
        // Task was cancelled
      }
    }
  }

  /// Perform actual save and show feedback
  private func performSave() {
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
    indicatorTask?.cancel()

    showSavedIndicator = true

    indicatorTask = Task { [weak self] in
      do {
        try await Task.sleep(nanoseconds: self?.indicatorDuration ?? 1_500_000_000)
        self?.showSavedIndicator = false
      } catch {
        // Task was cancelled
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
}
