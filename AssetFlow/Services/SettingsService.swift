//
//  SettingsService.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/28.
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
}
