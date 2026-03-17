//  AssetFlow — snapshot-based portfolio management for macOS.
//  Copyright (C) 2026 Jen-Chien Chang
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
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
