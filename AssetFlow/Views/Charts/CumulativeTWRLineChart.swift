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

import Charts
import SwiftUI

/// Cumulative time-weighted return line chart (SPEC 12.4).
///
/// Displays cumulative TWR (%) over time. TWR values are stored as decimals
/// (e.g. 0.21 for 21%) and displayed as percentages.
/// No click-to-navigate behavior per SPEC 12.4.
struct CumulativeTWRLineChart: View {
  let dataPoints: [DashboardDataPoint]
  let totalSnapshotCount: Int
  @Binding var timeRange: ChartTimeRange

  private var filteredPoints: [DashboardDataPoint] {
    let filtered = ChartDataService.filter(dataPoints, range: timeRange)
    guard timeRange != .all else { return filtered }
    return ChartDataService.rebasedTWR(filtered)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Cumulative TWR")
        .font(.headline)

      ChartTimeRangeSelector(selection: $timeRange)

      chartContent
    }
    .padding()
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .glassCard()
    .accessibilityLabel("Cumulative time-weighted return chart")
  }

  @ViewBuilder
  private var chartContent: some View {
    let points = filteredPoints
    if totalSnapshotCount < 2 {
      emptyMessage("Insufficient data (need at least 2 snapshots)")
    } else if points.isEmpty {
      emptyMessage("Cannot calculate returns for selected period")
    } else {
      SingleSeriesLineChart(
        data: points,
        dateKeyPath: \.date,
        valueOf: { $0.value.doubleValue * 100 },
        color: .orange,
        height: ChartConstants.dashboardChartHeight,
        yAxisLabel: { Decimal($0).formattedPercentage() },
        tooltipContent: { point in
          ChartTooltipView {
            Text(point.date.settingsFormatted())
              .font(.caption2)
            Text((point.value * 100).formattedPercentage())
              .font(.caption.bold())
          }
        }
      )
    }
  }

  private func emptyMessage(_ text: LocalizedStringKey) -> some View {
    ChartEmptyMessage(text: text, height: ChartConstants.dashboardChartHeight)
  }
}
