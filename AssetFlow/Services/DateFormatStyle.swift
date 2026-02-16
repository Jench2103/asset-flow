//
//  DateFormatStyle.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation

/// User-selectable date display format.
///
/// Maps to `Date.FormatStyle.DateStyle` for rendering. Uses stable `String` raw
/// values for UserDefaults persistence.
enum DateFormatStyle: String, CaseIterable {
  case numeric
  case abbreviated
  case long
  case complete

  /// The corresponding `Date.FormatStyle.DateStyle`.
  var dateStyle: Date.FormatStyle.DateStyle {
    switch self {
    case .numeric: .numeric
    case .abbreviated: .abbreviated
    case .long: .long
    case .complete: .complete
    }
  }

  /// Localized display name for pickers.
  var localizedName: String {
    switch self {
    case .numeric:
      String(localized: "Numeric", table: "Settings")

    case .abbreviated:
      String(localized: "Abbreviated", table: "Settings")

    case .long:
      String(localized: "Long", table: "Settings")

    case .complete:
      String(localized: "Complete", table: "Settings")
    }
  }

  /// Preview string showing a date in this format.
  func preview(for date: Date) -> String {
    date.formatted(date: dateStyle, time: .omitted)
  }
}
