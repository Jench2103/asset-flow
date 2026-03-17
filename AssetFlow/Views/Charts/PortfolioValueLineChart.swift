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

/// Portfolio value over time line chart (SPEC 12.2).
///
/// Displays total portfolio value at each snapshot date with time range filtering.
/// Supports hover tooltip with RuleMark annotation and click-to-navigate to snapshot.
struct PortfolioValueLineChart: View {
  let dataPoints: [DashboardDataPoint]
  @Binding var timeRange: ChartTimeRange
  var onSelectSnapshot: ((Date) -> Void)?

  private var filteredPoints: [DashboardDataPoint] {
    ChartDataService.filter(dataPoints, range: timeRange)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Portfolio Value Over Time")
        .font(.headline)

      ChartTimeRangeSelector(selection: $timeRange)

      chartContent
    }
    .padding()
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .glassCard()
    .accessibilityLabel("Portfolio value history chart")
  }

  @ViewBuilder
  private var chartContent: some View {
    let points = filteredPoints
    if dataPoints.isEmpty {
      emptyMessage("No portfolio data available")
    } else if points.isEmpty {
      emptyMessage("No data for selected period")
    } else {
      SingleSeriesLineChart(
        data: points,
        dateKeyPath: \.date,
        valueOf: { $0.value.doubleValue },
        color: .blue,
        height: ChartConstants.dashboardChartHeight,
        tooltipContent: { point in
          ChartTooltipView {
            Text(point.date.settingsFormatted())
              .font(.caption2)
            Text(point.value.formatted(currency: SettingsService.shared.mainCurrency))
              .font(.caption.bold())
          }
        },
        onTapDate: onSelectSnapshot
      )
    }
  }

  private func emptyMessage(_ text: LocalizedStringKey) -> some View {
    ChartEmptyMessage(text: text, height: ChartConstants.dashboardChartHeight)
  }
}
