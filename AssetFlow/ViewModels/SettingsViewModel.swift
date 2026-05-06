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

  /// Set when the user tries to enable reminders but the OS reports
  /// authorization as denied. The view binds this to an alert.
  var showAuthorizationDeniedAlert: Bool = false

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
    reminderTask = Task { [weak self] in
      guard let self else { return }
      if newValue {
        var status = await reminderService.authorizationStatus()
        if status == .notDetermined {
          status = await reminderService.requestAuthorization()
        }
        switch status {
        case .authorized, .provisional:
          settingsService.snapshotReminderEnabled = true
          await reminderService.reschedule(
            config: settingsService.snapshotReminderConfig)

        default:
          // Authorization not granted: revert and surface alert.
          isReminderEnabled = false
          settingsService.snapshotReminderEnabled = false
          showAuthorizationDeniedAlert = true
        }
      } else {
        settingsService.snapshotReminderEnabled = false
        await reminderService.reschedule(config: nil)
      }
    }
  }

  /// Mutates `settingsService.snapshotReminderConfig` in place via `transform`,
  /// then triggers a (debounced) reschedule. Centralizes the persist + reload
  /// pattern so each property `didSet` is one line.
  private func updateReminderConfig(
    _ transform: (inout SnapshotReminderConfig) -> Void
  ) {
    var config = settingsService.snapshotReminderConfig
    transform(&config)
    settingsService.snapshotReminderConfig = config
    scheduleReminderRefresh()
  }

  /// Schedules a reminder reschedule, coalescing rapid edits (e.g. dragging a
  /// `Stepper` or holding a `Picker` open). Each call cancels the prior
  /// pending task; only the most recent change actually runs `reschedule`.
  private func scheduleReminderRefresh() {
    guard isReminderEnabled else { return }
    reminderTask?.cancel()
    reminderTask = Task { [weak self] in
      // Small debounce window so a burst of didSets coalesces into one
      // reschedule. Cancellation here is silent — Task.sleep throws on
      // cancellation and we treat that as "a newer change superseded us".
      try? await Task.sleep(for: .milliseconds(150))
      guard !Task.isCancelled, let self else { return }
      await reminderService.reschedule(
        config: settingsService.snapshotReminderConfig)
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
