//
//  ChartTimeRangeSelector.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import SwiftUI

/// Reusable picker for chart time range selection (SPEC 12).
///
/// Displays all `ChartTimeRange` cases (1W/1M/3M/6M/1Y/3Y/5Y/All)
/// as compact capsule buttons.
struct ChartTimeRangeSelector: View {
  @Binding var selection: ChartTimeRange

  var body: some View {
    HStack(spacing: 4) {
      ForEach(ChartTimeRange.allCases) { range in
        Button {
          withAnimation(AnimationConstants.chart) { selection = range }
        } label: {
          let isSelected = selection == range
          Text(range.rawValue)
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(
              isSelected
                ? AnyShapeStyle(.tint.opacity(0.15))
                : AnyShapeStyle(.clear)
            )
            .foregroundStyle(isSelected ? .primary : .secondary)
            .clipShape(Capsule())
            .overlay(
              Capsule()
                .stroke(
                  isSelected
                    ? AnyShapeStyle(.tint.opacity(0.3))
                    : AnyShapeStyle(.clear),
                  lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .helpWhenUnlocked("Show \(range.rawValue) time range")
      }
    }
  }
}
