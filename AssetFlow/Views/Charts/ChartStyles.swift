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

  /// Standard card corner radius for dashboard cards.
  static let cardCornerRadius: CGFloat = 12

  /// Compact badge horizontal padding (for platform badges).
  static let compactBadgePaddingH: CGFloat = 5

  /// Compact badge vertical padding (for platform badges).
  static let compactBadgePaddingV: CGFloat = 2

  /// Standard badge horizontal padding (for asset count badges).
  static let badgePaddingH: CGFloat = 6

  /// Standard badge vertical padding (for asset count badges).
  static let badgePaddingV: CGFloat = 2

  /// Returns a color for a category at the given index, cycling through the palette.
  static func color(forIndex index: Int) -> Color {
    categoryColors[index % categoryColors.count]
  }
}

// MARK: - Glass Card Modifier

/// Applies a frosted glass material background with subtle shadows and border,
/// following the Liquid Glass design system.
struct GlassCardModifier: ViewModifier {
  @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

  func body(content: Content) -> some View {
    content
      .background(reduceTransparency ? .regularMaterial : .ultraThinMaterial)
      .clipShape(RoundedRectangle(cornerRadius: ChartConstants.cardCornerRadius))
      .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
      .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
      .overlay(
        RoundedRectangle(cornerRadius: ChartConstants.cardCornerRadius)
          .stroke(.primary.opacity(0.1), lineWidth: 0.5)
      )
  }
}

extension View {
  /// Applies the glass card treatment: material background, rounded corners, shadows, and border.
  func glassCard() -> some View {
    modifier(GlassCardModifier())
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
  let text: LocalizedStringKey
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
