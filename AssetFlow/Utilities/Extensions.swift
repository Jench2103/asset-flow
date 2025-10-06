//
//  Extensions.swift
//  AssetFlow
//
//  Created by Jen-Chien Chang on 2025/10/6.
//

import Foundation

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
