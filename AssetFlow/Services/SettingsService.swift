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

  private init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults

    // Load main currency from UserDefaults or use default
    self.mainCurrency =
      userDefaults.string(forKey: Constants.UserDefaultsKeys.preferredCurrency)
      ?? Constants.DefaultValues.defaultCurrency
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
