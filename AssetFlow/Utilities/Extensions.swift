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

  func formatted(currency: String = "USD", locale: Locale = .current) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .currency
    formatter.currencyCode = currency
    formatter.locale = locale
    return formatter.string(from: NSDecimalNumber(decimal: self)) ?? "\(self)"
  }

  func formattedPercentage(decimals: Int = 2) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .percent
    formatter.minimumFractionDigits = decimals
    formatter.maximumFractionDigits = decimals
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
    insert(newCategory)
    return newCategory
  }
}

// MARK: - String Extensions
extension String {
  /// Normalizes a string for identity comparison (SPEC 6.1):
  /// trims whitespace, collapses internal runs of whitespace, lowercases.
  var normalizedForIdentity: String {
    self
      .trimmingCharacters(in: .whitespaces)
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .lowercased()
  }
}

// MARK: - Date Extensions
extension Date {
  func formatted(style: DateFormatter.Style = .medium) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = style
    formatter.timeStyle = .none
    return formatter.string(from: self)
  }

  func formattedWithTime(
    dateStyle: DateFormatter.Style = .medium, timeStyle: DateFormatter.Style = .short
  ) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = dateStyle
    formatter.timeStyle = timeStyle
    return formatter.string(from: self)
  }

  /// Formats the date using the system's short date format (date only, no time).
  var formattedDate: String {
    formatted(style: .short)
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
