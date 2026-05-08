//  AssetFlow — snapshot-based portfolio management for macOS.
//  Copyright (C) 2026 Jen-Chien Chang
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import UserNotifications

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

  /// The reminder service used to schedule/cancel notifications.
  private let reminderService: SnapshotReminderService

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

  // MARK: - Snapshot Reminder

  /// Whether snapshot reminder notifications are enabled.
  ///
  /// Toggling triggers an async authorization check. Tests should
  /// `await viewModel.reminderTask?.value` to wait for the operation.
  var isReminderEnabled: Bool {
    didSet {
      guard isReminderEnabled != oldValue else { return }
      handleReminderToggleChange(newValue: isReminderEnabled)
    }
  }

  /// Configured cadence preset.
  var reminderFrequency: SnapshotReminderConfig.Frequency {
    didSet {
      guard reminderFrequency != oldValue else { return }
      updateReminderConfig { $0.frequency = reminderFrequency }
    }
  }

  /// Configured weekday (1...7, Sunday = 1) for weekly/bi-weekly cadences.
  var reminderWeekday: Int {
    didSet {
      guard reminderWeekday != oldValue else { return }
      updateReminderConfig { $0.weekday = reminderWeekday }
    }
  }

  /// Configured day-of-month (1...28) for monthly cadence.
  var reminderDayOfMonth: Int {
    didSet {
      guard reminderDayOfMonth != oldValue else { return }
      updateReminderConfig { $0.dayOfMonth = reminderDayOfMonth }
    }
  }

  /// Configured stride in days for the custom interval (`.interval`) cadence.
  var reminderIntervalDays: Int {
    didSet {
      guard reminderIntervalDays != oldValue else { return }
      updateReminderConfig { $0.intervalDays = reminderIntervalDays }
    }
  }

  /// Configured time-of-day; only the hour and minute components matter.
  var reminderTime: Date {
    didSet {
      let components = Calendar.current.dateComponents(
        [.hour, .minute], from: reminderTime)
      let stored = settingsService.snapshotReminderConfig
      let newHour = components.hour ?? stored.hour
      let newMinute = components.minute ?? stored.minute
      guard newHour != stored.hour || newMinute != stored.minute else { return }
      updateReminderConfig {
        $0.hour = newHour
        $0.minute = newMinute
      }
    }
  }

  /// Cause of the most recent failure to enable snapshot reminders, or
  /// `nil` (or `.authorized`) when no alert should be shown. Bound by the
  /// view to two alerts: the user-denied case (link to System Settings)
  /// and the registration-failure case (suggest /Applications + GitHub).
  var authorizationFailureKind: SnapshotReminderService.AuthorizationResult?

  /// Task handle for in-flight reminder operations, exposed for testability.
  private(set) var reminderTask: Task<Void, Never>?

  init(
    settingsService: SettingsService? = nil,
    authenticationService: AuthenticationService? = nil,
    reminderService: SnapshotReminderService? = nil
  ) {
    let resolvedSettingsService = settingsService ?? SettingsService.shared
    let resolvedAuthService = authenticationService ?? AuthenticationService.shared
    let resolvedReminderService = reminderService ?? SnapshotReminderService.shared
    self.settingsService = resolvedSettingsService
    self.authService = resolvedAuthService
    self.reminderService = resolvedReminderService
    self.selectedCurrency = resolvedSettingsService.mainCurrency
    self.selectedDateFormat = resolvedSettingsService.dateFormat
    self.defaultPlatformString = resolvedSettingsService.defaultPlatform
    self.isAppLockEnabled = resolvedAuthService.isAppLockEnabled
    self.appSwitchTimeout = resolvedAuthService.appSwitchTimeout
    self.screenLockTimeout = resolvedAuthService.screenLockTimeout

    let storedConfig = resolvedSettingsService.snapshotReminderConfig
    self.isReminderEnabled = resolvedSettingsService.snapshotReminderEnabled
    self.reminderFrequency = storedConfig.frequency
    self.reminderWeekday = storedConfig.weekday
    self.reminderDayOfMonth = storedConfig.dayOfMonth
    self.reminderIntervalDays = storedConfig.intervalDays
    self.reminderTime = Self.makeDate(
      hour: storedConfig.hour, minute: storedConfig.minute)
  }

  // MARK: - Reminder helpers

  private func handleReminderToggleChange(newValue: Bool) {
    reminderTask?.cancel()
    reminderTask = Task { [weak self] in
      guard let self else { return }
      let result = await reminderService.setEnabled(newValue)
      let persisted = settingsService.snapshotReminderEnabled
      if isReminderEnabled != persisted {
        isReminderEnabled = persisted
      }
      authorizationFailureKind = result == .authorized ? nil : result
    }
  }

  /// Persists the config change synchronously, then debounces (150 ms) a
  /// reconcile through the manager's serial queue. The debounce coalesces
  /// a burst of edits — e.g., while the user is dragging a Stepper.
  private func updateReminderConfig(
    _ transform: (inout SnapshotReminderConfig) -> Void
  ) {
    var config = settingsService.snapshotReminderConfig
    transform(&config)
    settingsService.snapshotReminderConfig = config

    guard isReminderEnabled else { return }

    reminderTask?.cancel()
    reminderTask = Task { [weak self] in
      try? await Task.sleep(for: .milliseconds(150))
      guard !Task.isCancelled, let self else { return }
      await reminderService.reconcile()
    }
  }

  private static func makeDate(hour: Int, minute: Int) -> Date {
    var calendar = Calendar.current
    calendar.timeZone = TimeZone.current
    let now = Date()
    return calendar.date(
      bySettingHour: hour, minute: minute, second: 0, of: now)
      ?? now
  }
}
