//
//  ChartStyles.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Charts
import SwiftUI

/// Shared chart layout constants and color palette.
enum ChartConstants {
  /// Standard chart height for detail views.
  static let standardChartHeight: CGFloat = 250

  /// Compact chart height for dashboard cards.
  static let dashboardChartHeight: CGFloat = 200

  /// Color palette for multi-category charts (up to 10 distinct colors).
  static let categoryColors: [Color] = [
    .blue, .green, .orange, .purple, .red,
    .cyan, .pink, .brown, .mint, .indigo,
  ]

  /// Returns a color for a category at the given index, cycling through the palette.
  static func color(forIndex index: Int) -> Color {
    categoryColors[index % categoryColors.count]
  }
}

// MARK: - Chart Helpers

/// Shared utility functions for chart interactions.
enum ChartHelpers {
  /// Finds the nearest data point date to a cursor location in a chart.
  static func findNearestDate<T>(
    at location: CGPoint, in proxy: ChartProxy,
    points: [T], dateKeyPath: KeyPath<T, Date>
  ) -> Date? {
    guard let date: Date = proxy.value(atX: location.x) else { return nil }

    return points.min(by: {
      abs($0[keyPath: dateKeyPath].timeIntervalSince(date))
        < abs($1[keyPath: dateKeyPath].timeIntervalSince(date))
    })?[keyPath: dateKeyPath]
  }
}

// MARK: - Shared Chart Views

/// Empty state message for charts when no data is available.
struct ChartEmptyMessage: View {
  let text: String
  let height: CGFloat

  var body: some View {
    Text(text)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity)
      .frame(height: height)
  }
}

/// Generic tooltip wrapper with consistent styling across all charts.
struct ChartTooltipView<Content: View>: View {
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(spacing: 2) {
      content()
    }
    .padding(6)
    .background(.regularMaterial)
    .clipShape(RoundedRectangle(cornerRadius: 4))
  }
}
