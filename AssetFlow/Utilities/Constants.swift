//
//  Constants.swift
//  AssetFlow
//
//  Created by Jen-Chien Chang on 2025/10/6.
//

import Foundation

enum Constants {
  enum AppInfo {
    static let name = "AssetFlow"
    static let version = "1.0.0"
    static let buildNumber = "1"
  }

  enum DefaultValues {
    static let defaultCurrency = "USD"
    static let minimumPasswordLength = 8
    static let maxDecimalPlaces = 2
  }

  enum UserDefaultsKeys {
    static let hasLaunchedBefore = "hasLaunchedBefore"
    static let preferredCurrency = "preferredCurrency"
    static let enableBiometricAuth = "enableBiometricAuth"
    static let lastSyncDate = "lastSyncDate"
  }

  enum CloudKit {
    static let containerIdentifier = "iCloud.com.assetflow.AssetFlow"
  }
}
