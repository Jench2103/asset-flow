//
//  Constants.swift
//  AssetFlow
//
//  Created by Jen-Chien Chang on 2025/10/6.
//

import Foundation

enum Constants {
  enum AppInfo {
    static let name = Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "AssetFlow"
    static let version =
      Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    static let buildNumber =
      Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"
    static let commit = Bundle.main.infoDictionary?["AppCommit"] as? String ?? "unknown"
    static let developerName = "Jen-Chien Chang"
    static let copyright = "Copyright © 2026 Jen-Chien Chang"
    static let license = "Apache License 2.0"
    static let repositoryURL = URL(string: "https://github.com/Jench2103/asset-flow")!
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
