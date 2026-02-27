//
//  Extensions.swift
//  AssetFlow
//
//  Created by Jen-Chien Chang on 2025/10/6.
//

import Foundation
import SwiftData

// MARK: - Decimal Extensions
extension Decimal {
  var doubleValue: Double {
    NSDecimalNumber(decimal: self).doubleValue
  }

  private static var currencyFormatters: [String: NumberFormatter] = [:]

  func formatted(currency: String = "USD", locale: Locale = .current) -> String {
    let key = "\(currency)-\(locale.identifier)"
    let formatter: NumberFormatter
    if let cached = Self.currencyFormatters[key] {
      formatter = cached
    } else {
      let f = NumberFormatter()
      f.numberStyle = .currency
      f.currencyCode = currency
      f.locale = locale
      Self.currencyFormatters[key] = f
      formatter = f
    }
    return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "\(self)"
  }

  private static var percentageFormatters: [Int: NumberFormatter] = [:]

  /// Formats a percentage value for display.
  ///
  /// **IMPORTANT:** Expects percentage-scale input (0-100 range).
  /// For decimal ratios (0.0-1.0) from CalculationService,
  /// multiply by 100 first: `(ratio * 100).formattedPercentage()`
  ///
  /// Examples:
  ///   - Input: Decimal(45.67) → Output: "45.67%"
  ///   - Input: Decimal(0.4567) * 100 → Output: "45.67%"
  ///
  /// - Parameter decimals: Number of decimal places (default: 2)
  /// - Returns: Formatted percentage string
  func formattedPercentage(decimals: Int = 2) -> String {
    let formatter: NumberFormatter
    if let cached = Self.percentageFormatters[decimals] {
      formatter = cached
    } else {
      let f = NumberFormatter()
      f.numberStyle = .percent
      f.minimumFractionDigits = decimals
      f.maximumFractionDigits = decimals
      Self.percentageFormatters[decimals] = f
      formatter = f
    }
    return formatter.string(from: NSDecimalNumber(decimal: self / 100)) ?? "\(self)%"
  }
}

// MARK: - ModelContext Extensions
extension ModelContext {
  /// Finds an existing asset by normalized (name, platform) or creates a new one.
  func findOrCreateAsset(name: String, platform: String) -> Asset {
    let normalizedName = name.normalizedForIdentity
    let normalizedPlatform = platform.normalizedForIdentity

    let descriptor = FetchDescriptor<Asset>()
    let allAssets = (try? fetch(descriptor)) ?? []

    if let existing = allAssets.first(where: {
      $0.normalizedName == normalizedName && $0.normalizedPlatform == normalizedPlatform
    }) {
      return existing
    }

    let newAsset = Asset(name: name, platform: platform)
    insert(newAsset)
    return newAsset
  }

  /// Resolves a category by name, reusing an existing one (case-insensitive) or creating a new one.
  func resolveCategory(name: String) -> Category? {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return nil }

    let normalizedInput = trimmed.lowercased()

    let descriptor = FetchDescriptor<Category>()
    let allCategories = (try? fetch(descriptor)) ?? []

    if let existing = allCategories.first(where: { $0.name.lowercased() == normalizedInput }) {
      return existing
    }

    let newCategory = Category(name: trimmed)
    let maxOrder = allCategories.map(\.displayOrder).max() ?? -1
    newCategory.displayOrder = maxOrder + 1
    insert(newCategory)
    return newCategory
  }
}

// MARK: - String Extensions
extension String {
  /// Normalizes a string for identity comparison (SPEC 6.1):
  /// trims whitespace, collapses internal runs of whitespace, lowercases.
  var normalizedForIdentity: String {
    let trimmed = self.trimmingCharacters(in: .whitespaces)
    var result = ""
    result.reserveCapacity(trimmed.count)
    var previousWasWhitespace = false
    for char in trimmed {
      if char.isWhitespace {
        if !previousWasWhitespace {
          result.append(" ")
          previousWasWhitespace = true
        }
      } else {
        result.append(char)
        previousWasWhitespace = false
      }
    }
    return result.lowercased()
  }
}

// MARK: - Date Extensions
extension Date {
  private static var dateStyleFormatters: [DateFormatter.Style: DateFormatter] = [:]

  func formatted(style: DateFormatter.Style = .medium) -> String {
    let formatter: DateFormatter
    if let cached = Self.dateStyleFormatters[style] {
      formatter = cached
    } else {
      let f = DateFormatter()
      f.dateStyle = style
      f.timeStyle = .none
      Self.dateStyleFormatters[style] = f
      formatter = f
    }
    return formatter.string(from: self)
  }

  private static var dateTimeFormatters: [String: DateFormatter] = [:]

  func formattedWithTime(
    dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short
  ) -> String {
    let key = "\(dateStyle.rawValue)-\(timeStyle.rawValue)"
    let formatter: DateFormatter
    if let cached = Self.dateTimeFormatters[key] {
      formatter = cached
    } else {
      let f = DateFormatter()
      f.dateStyle = dateStyle
      f.timeStyle = timeStyle
      Self.dateTimeFormatters[key] = f
      formatter = f
    }
    return formatter.string(from: self)
  }

  /// Formats the date using the system's short date format (date only, no time).
  var formattedDate: String {
    formatted(style: .short)
  }

  /// Formats the date using the shared settings service's date format preference.
  @MainActor
  func settingsFormatted() -> String {
    self.formatted(date: SettingsService.shared.dateFormat.dateStyle, time: .omitted)
  }

  /// Formats the date using the given settings service's date format preference.
  @MainActor
  func settingsFormatted(using service: SettingsService) -> String {
    self.formatted(date: service.dateFormat.dateStyle, time: .omitted)
  }

  var startOfDay: Date {
    Calendar.current.startOfDay(for: self)
  }

  var endOfDay: Date {
    var components = DateComponents()
    components.day = 1
    components.second = -1
    return Calendar.current.date(byAdding: components, to: startOfDay) ?? self
  }
}
