//
//  PortfolioValueLineChart.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
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
