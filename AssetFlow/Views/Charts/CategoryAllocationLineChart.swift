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

/// Single-category allocation percentage line chart for CategoryDetailView.
///
/// Shows allocation % over time with a green line and a smart dynamic Y-axis.
/// When a target allocation is set, displays a dashed orange reference line.
/// Includes time range selector and hover tooltip.
struct CategoryAllocationLineChart: View {
  let entries: [CategoryAllocationHistoryEntry]
  @Binding var timeRange: ChartTimeRange
  let targetAllocationPercentage: Decimal?

  private var filteredEntries: [CategoryAllocationHistoryEntry] {
    ChartDataService.filter(entries, range: timeRange)
  }

  var body: some View {
    ChartTimeRangeSelector(selection: $timeRange)

    chartContent
  }

  @ViewBuilder
  private var chartContent: some View {
    let points = filteredEntries
    if entries.isEmpty {
      emptyMessage("No allocation history")
    } else if points.isEmpty {
      emptyMessage("No data for selected period")
    } else {
      SingleSeriesLineChart(
        data: points,
        dateKeyPath: \.date,
        valueOf: { $0.allocationPercentage.doubleValue },
        color: .green,
        height: ChartConstants.standardChartHeight,
        yAxisLabel: { Decimal(Int($0.rounded())).formattedPercentage() },
        tooltipContent: { entry in
          ChartTooltipView {
            Text(entry.date.settingsFormatted())
              .font(.caption2)
            Text(entry.allocationPercentage.formattedPercentage())
              .font(.caption.bold())
          }
        },
        yDomain: { dataMin, dataMax in
          var adjustedMin = dataMin
          var adjustedMax = dataMax
          if let target = targetAllocationPercentage?.doubleValue {
            adjustedMin = min(adjustedMin, target)
            adjustedMax = max(adjustedMax, target)
          }
          if adjustedMin == adjustedMax {
            adjustedMin = max(0, adjustedMin - 5)
            adjustedMax = min(100, adjustedMax + 5)
          }
          return (adjustedMin, adjustedMax)
        },
        extraContent: {
          if let target = targetAllocationPercentage {
            RuleMark(y: .value("Target", target.doubleValue))
              .foregroundStyle(.orange.opacity(0.6))
              .lineStyle(StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
              .annotation(position: .top, alignment: .leading) {
                Text("Target: \(target.formattedPercentage())")
                  .font(.caption2)
                  .foregroundStyle(.orange)
              }
          }
        }
      )
    }
  }

  private func emptyMessage(_ text: LocalizedStringKey) -> some View {
    ChartEmptyMessage(text: text, height: ChartConstants.standardChartHeight)
  }
}
