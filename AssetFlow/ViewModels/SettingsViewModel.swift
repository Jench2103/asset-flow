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

  /// Available currencies for picker
  var availableCurrencies: [Currency] {
    CurrencyService.shared.currencies
  }

  init(settingsService: SettingsService? = nil) {
    let resolvedSettingsService = settingsService ?? SettingsService.shared
    self.settingsService = resolvedSettingsService
    self.selectedCurrency = resolvedSettingsService.mainCurrency
  }
}
