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

  /// Selected date format
  var selectedDateFormat: DateFormatStyle {
    didSet {
      guard selectedDateFormat != oldValue else { return }
      settingsService.dateFormat = selectedDateFormat
    }
  }

  /// Default platform for imports
  var defaultPlatformString: String {
    didSet {
      guard defaultPlatformString != oldValue else { return }
      settingsService.defaultPlatform = defaultPlatformString
    }
  }

  /// Available currencies for picker
  var availableCurrencies: [Currency] {
    CurrencyService.shared.currencies
  }

  /// Available date formats for picker, deduplicated by preview output
  /// (e.g., in Traditional Chinese, abbreviated and long produce identical strings)
  var availableDateFormats: [DateFormatStyle] {
    let referenceDate = Date()
    var seenPreviews: Set<String> = []
    return DateFormatStyle.allCases.filter { format in
      let preview = format.preview(for: referenceDate)
      return seenPreviews.insert(preview).inserted
    }
  }

  init(settingsService: SettingsService? = nil) {
    let resolvedSettingsService = settingsService ?? SettingsService.shared
    self.settingsService = resolvedSettingsService
    self.selectedCurrency = resolvedSettingsService.mainCurrency
    self.selectedDateFormat = resolvedSettingsService.dateFormat
    self.defaultPlatformString = resolvedSettingsService.defaultPlatform
  }
}
