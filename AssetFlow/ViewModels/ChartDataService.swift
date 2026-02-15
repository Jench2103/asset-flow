//
//  ChartDataService.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation

/// Time range options for chart zoom selectors (SPEC 12).
enum ChartTimeRange: String, CaseIterable, Identifiable {
  case oneWeek = "1W"
  case oneMonth = "1M"
  case threeMonths = "3M"
  case sixMonths = "6M"
  case oneYear = "1Y"
  case threeYears = "3Y"
  case fiveYears = "5Y"
  case all = "All"

  var id: String { rawValue }

  /// Returns the start date for this range relative to a reference date,
  /// or nil for `.all` (no filtering).
  func startDate(from referenceDate: Date) -> Date? {
    switch self {
    case .oneWeek:
      return Calendar.current.date(byAdding: .day, value: -7, to: referenceDate)

    case .oneMonth:
      return Calendar.current.date(byAdding: .month, value: -1, to: referenceDate)

    case .threeMonths:
      return Calendar.current.date(byAdding: .month, value: -3, to: referenceDate)

    case .sixMonths:
      return Calendar.current.date(byAdding: .month, value: -6, to: referenceDate)

    case .oneYear:
      return Calendar.current.date(byAdding: .year, value: -1, to: referenceDate)

    case .threeYears:
      return Calendar.current.date(byAdding: .year, value: -3, to: referenceDate)

    case .fiveYears:
      return Calendar.current.date(byAdding: .year, value: -5, to: referenceDate)

    case .all:
      return nil
    }
  }
}

/// Protocol for chart data types that can be filtered by date.
protocol ChartFilterable {
  var chartDate: Date { get }
}

extension DashboardDataPoint: ChartFilterable {
  var chartDate: Date { date }
}

extension CategoryValueHistoryEntry: ChartFilterable {
  var chartDate: Date { date }
}

extension CategoryAllocationHistoryEntry: ChartFilterable {
  var chartDate: Date { date }
}

/// Stateless chart data filtering and formatting service.
///
/// Filters data points by time range using the latest point's date as reference.
/// Provides abbreviated axis labels for large values (K/M/B).
enum ChartDataService {

  // MARK: - Filter

  /// Filters chart data points by time range.
  ///
  /// Uses the latest data point's date as the reference for range calculation,
  /// not `Date.now`, for consistency with the portfolio timeline.
  static func filter<T: ChartFilterable>(_ items: [T], range: ChartTimeRange) -> [T] {
    guard !items.isEmpty else { return [] }
    guard range != .all else { return items }
    guard let latestDate = items.map(\.chartDate).max(),
      let startDate = range.startDate(from: latestDate)
    else { return items }

    return items.filter { $0.chartDate >= startDate }
  }

  // MARK: - Abbreviated Labels

  /// Returns an abbreviated string for large numeric values.
  ///
  /// - 3,000,000,000 → "3B"
  /// - 2,000,000 → "2M"
  /// - 5,000 → "5K"
  /// - 1,500 → "1.5K"
  /// - 500 → "500"
  static func abbreviatedLabel(for value: Double) -> String {
    let absValue = abs(value)
    let sign = value < 0 ? "-" : ""

    if absValue >= 1_000_000_000 {
      let billions = absValue / 1_000_000_000
      return sign + formatAbbreviated(billions, suffix: "B")
    } else if absValue >= 1_000_000 {
      let millions = absValue / 1_000_000
      return sign + formatAbbreviated(millions, suffix: "M")
    } else if absValue >= 1_000 {
      let thousands = absValue / 1_000
      return sign + formatAbbreviated(thousands, suffix: "K")
    } else {
      return sign + formatWhole(absValue)
    }
  }

  // MARK: - Private Helpers

  private static func formatAbbreviated(_ value: Double, suffix: String) -> String {
    let formatted = String(format: "%.1f", value)
    if formatted.hasSuffix(".0") {
      return String(formatted.dropLast(2)) + suffix
    }
    return formatted + suffix
  }

  private static func formatWhole(_ value: Double) -> String {
    if value == value.rounded(.down) {
      return "\(Int(value))"
    }
    return String(format: "%.0f", value)
  }
}
