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

/// Service for managing app-wide settings
///
/// Uses UserDefaults for persistence. Settings include:
/// - Main currency for displaying portfolio values
///
/// Supports dependency injection for test isolation via `createForTesting()`.
@Observable
@MainActor
class SettingsService {
  static let shared = SettingsService()

  /// The UserDefaults instance used for persistence
  private let userDefaults: UserDefaults

  /// The main currency used for displaying portfolio values
  var mainCurrency: String {
    didSet {
      userDefaults.set(mainCurrency, forKey: Constants.UserDefaultsKeys.preferredCurrency)
    }
  }

  /// The date display format
  var dateFormat: DateFormatStyle {
    didSet {
      userDefaults.set(dateFormat.rawValue, forKey: Constants.UserDefaultsKeys.dateFormat)
    }
  }

  /// The default platform pre-filled in import
  var defaultPlatform: String {
    didSet {
      userDefaults.set(defaultPlatform, forKey: Constants.UserDefaultsKeys.defaultPlatform)
    }
  }

  /// The user-defined display order for platforms
  var platformOrder: [String] {
    didSet {
      userDefaults.set(platformOrder, forKey: Constants.UserDefaultsKeys.platformOrder)
    }
  }

  /// Whether to hide stale assets (assets missing from the latest snapshot)
  /// in the asset list.
  var hideStaleAssets: Bool {
    didSet {
      userDefaults.set(hideStaleAssets, forKey: Constants.UserDefaultsKeys.hideStaleAssets)
    }
  }

  /// Whether the user has ever successfully authorized AssetFlow notifications.
  ///
  /// Used to distinguish two failure modes when re-enabling reminders fails:
  /// a real "user disabled it in System Settings" denial (this flag is `true`)
  /// versus a registration failure where the OS never recorded an entry
  /// (this flag is `false`). The flag is sticky — once set to true it remains
  /// true across reinstalls of the same UserDefaults suite.
  var hasNotificationsBeenAuthorized: Bool {
    didSet {
      userDefaults.set(
        hasNotificationsBeenAuthorized,
        forKey: Constants.UserDefaultsKeys.hasNotificationsBeenAuthorized)
    }
  }

  /// Whether snapshot reminder notifications are enabled.
  var snapshotReminderEnabled: Bool {
    didSet {
      userDefaults.set(
        snapshotReminderEnabled,
        forKey: Constants.UserDefaultsKeys.snapshotReminderEnabled)
    }
  }

  /// User-configured cadence for snapshot reminder notifications.
  ///
  /// Persisted as a JSON-encoded `Data` blob so the schema can evolve
  /// independently of UserDefaults' typed accessors.
  var snapshotReminderConfig: SnapshotReminderConfig {
    didSet {
      if let data = try? JSONEncoder().encode(snapshotReminderConfig) {
        userDefaults.set(
          data, forKey: Constants.UserDefaultsKeys.snapshotReminderConfig)
      }
    }
  }

  /// Future-dated snoozes the user has scheduled via the "Remind Tomorrow"
  /// notification action. Stored as data (not as `usernoted` requests
  /// directly) so they survive recurring-schedule reconciles. Cleared when
  /// the user disables reminders. JSON-encoded for forward-compatibility
  /// with potential per-snooze metadata.
  var activeSnoozes: [Date] {
    didSet {
      if let data = try? JSONEncoder().encode(activeSnoozes) {
        userDefaults.set(
          data, forKey: Constants.UserDefaultsKeys.activeSnoozes)
      }
    }
  }

  /// On-disk schema version for the notification architecture. Bumped when
  /// the identifier scheme or storage layout changes; gates one-shot
  /// migrations on first launch under newer code.
  var notificationsArchitectureVersion: Int {
    didSet {
      userDefaults.set(
        notificationsArchitectureVersion,
        forKey: Constants.UserDefaultsKeys.notificationsArchitectureVersion)
    }
  }

  private init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults

    self.mainCurrency =
      userDefaults.string(forKey: Constants.UserDefaultsKeys.preferredCurrency)
      ?? Constants.DefaultValues.defaultCurrency

    if let rawFormat = userDefaults.string(forKey: Constants.UserDefaultsKeys.dateFormat),
      let format = DateFormatStyle(rawValue: rawFormat)
    {
      self.dateFormat = format
    } else {
      self.dateFormat = Constants.DefaultValues.defaultDateFormat
    }

    self.defaultPlatform =
      userDefaults.string(forKey: Constants.UserDefaultsKeys.defaultPlatform)
      ?? Constants.DefaultValues.defaultPlatform

    self.platformOrder =
      userDefaults.stringArray(forKey: Constants.UserDefaultsKeys.platformOrder)
      ?? []

    self.hideStaleAssets =
      (userDefaults.object(forKey: Constants.UserDefaultsKeys.hideStaleAssets) as? Bool)
      ?? Constants.DefaultValues.defaultHideStaleAssets

    self.snapshotReminderEnabled =
      (userDefaults.object(forKey: Constants.UserDefaultsKeys.snapshotReminderEnabled)
        as? Bool)
      ?? Constants.DefaultValues.defaultSnapshotReminderEnabled

    if let data = userDefaults.data(
      forKey: Constants.UserDefaultsKeys.snapshotReminderConfig),
      let decoded = try? JSONDecoder().decode(
        SnapshotReminderConfig.self, from: data)
    {
      self.snapshotReminderConfig = decoded
    } else {
      self.snapshotReminderConfig = Constants.DefaultValues.defaultSnapshotReminderConfig
    }

    self.hasNotificationsBeenAuthorized =
      (userDefaults.object(
        forKey: Constants.UserDefaultsKeys.hasNotificationsBeenAuthorized)
        as? Bool) ?? false

    if let data = userDefaults.data(
      forKey: Constants.UserDefaultsKeys.activeSnoozes),
      let decoded = try? JSONDecoder().decode([Date].self, from: data)
    {
      self.activeSnoozes = decoded
    } else {
      self.activeSnoozes = []
    }

    self.notificationsArchitectureVersion =
      (userDefaults.object(
        forKey: Constants.UserDefaultsKeys.notificationsArchitectureVersion)
        as? Int) ?? 0
  }

  /// Creates an isolated instance for testing purposes
  ///
  /// Each call creates a new instance with its own temporary UserDefaults suite,
  /// ensuring complete test isolation with no shared state between tests.
  /// - Returns: A new SettingsService instance with isolated storage
  static func createForTesting() -> SettingsService {
    let suiteName = "com.assetflow.testing.\(UUID().uuidString)"
    guard let testDefaults = UserDefaults(suiteName: suiteName) else {
      preconditionFailure("Failed to create UserDefaults suite for testing")
    }
    return SettingsService(userDefaults: testDefaults)
  }

  /// Creates an instance backed by the supplied `UserDefaults` for testing.
  ///
  /// Useful for verifying persistence behavior across multiple instances
  /// sharing the same backing store.
  static func createForTesting(userDefaults: UserDefaults) -> SettingsService {
    SettingsService(userDefaults: userDefaults)
  }
}
