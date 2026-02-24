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
/// - App lock and re-lock timeout (via AuthenticationService)
@Observable
@MainActor
final class SettingsViewModel {
  /// The settings service for persistence
  private let settingsService: SettingsService

  /// The authentication service for app lock settings
  private let authService: AuthenticationService

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

  /// Task handle for the in-flight authentication request, exposed for testability.
  private(set) var authTask: Task<Void, Never>?

  /// Whether app lock is enabled
  var isAppLockEnabled: Bool {
    didSet {
      guard isAppLockEnabled != oldValue else { return }
      if isAppLockEnabled {
        // Reset timeouts to default if both were .never (from auto-disable).
        // Done before auth so the pickers update instantly.
        if authService.appSwitchTimeout == .never
          && authService.screenLockTimeout == .never
        {
          authService.appSwitchTimeout = .immediately
          authService.screenLockTimeout = .immediately
          appSwitchTimeout = .immediately
          screenLockTimeout = .immediately
        }
        // Verify identity before enabling — revert if auth fails
        authTask = Task {
          let success = await authService.authenticate()
          if success {
            authService.isAppLockEnabled = true
          } else {
            isAppLockEnabled = false
          }
        }
      } else {
        authService.isAppLockEnabled = false
        authService.isLocked = false
      }
    }
  }

  /// How long after switching apps before the app re-locks
  var appSwitchTimeout: ReLockTimeout {
    didSet {
      guard appSwitchTimeout != oldValue else { return }
      authService.appSwitchTimeout = appSwitchTimeout
      if appSwitchTimeout == .never && screenLockTimeout == .never {
        authService.isAppLockEnabled = false
        authService.isLocked = false
        isAppLockEnabled = false
      }
    }
  }

  /// How long after screen lock or sleep before the app re-locks
  var screenLockTimeout: ReLockTimeout {
    didSet {
      guard screenLockTimeout != oldValue else { return }
      authService.screenLockTimeout = screenLockTimeout
      if appSwitchTimeout == .never && screenLockTimeout == .never {
        authService.isAppLockEnabled = false
        authService.isLocked = false
        isAppLockEnabled = false
      }
    }
  }

  /// Whether biometric authentication (Touch ID) is available on this Mac
  var canUseBiometrics: Bool {
    authService.canEvaluatePolicy()
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

  init(
    settingsService: SettingsService? = nil,
    authenticationService: AuthenticationService? = nil
  ) {
    let resolvedSettingsService = settingsService ?? SettingsService.shared
    let resolvedAuthService = authenticationService ?? AuthenticationService.shared
    self.settingsService = resolvedSettingsService
    self.authService = resolvedAuthService
    self.selectedCurrency = resolvedSettingsService.mainCurrency
    self.selectedDateFormat = resolvedSettingsService.dateFormat
    self.defaultPlatformString = resolvedSettingsService.defaultPlatform
    self.isAppLockEnabled = resolvedAuthService.isAppLockEnabled
    self.appSwitchTimeout = resolvedAuthService.appSwitchTimeout
    self.screenLockTimeout = resolvedAuthService.screenLockTimeout
  }
}
