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
    static let maxDecimalPlaces = 2
    static let defaultDateFormat = DateFormatStyle.abbreviated
    static let defaultPlatform = ""
  }

  enum UserDefaultsKeys {
    static let preferredCurrency = "preferredCurrency"
    static let dateFormat = "dateFormat"
    static let defaultPlatform = "defaultPlatform"
  }
}
