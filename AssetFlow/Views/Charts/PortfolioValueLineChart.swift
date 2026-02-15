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

  @State private var hoveredDate: Date?

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
    .background(.fill.quaternary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  @ViewBuilder
  private var chartContent: some View {
    let points = filteredPoints
    if dataPoints.isEmpty {
      emptyMessage("No portfolio data available")
    } else if points.isEmpty {
      emptyMessage("No data for selected period")
    } else if points.count == 1 {
      singlePointChart(points)
    } else {
      lineChart(points)
    }
  }

  private func lineChart(_ points: [DashboardDataPoint]) -> some View {
    Chart(points, id: \.date) { point in
      LineMark(
        x: .value("Date", point.date),
        y: .value("Value", point.value.doubleValue)
      )
      .foregroundStyle(.blue)

      PointMark(
        x: .value("Date", point.date),
        y: .value("Value", point.value.doubleValue)
      )
      .foregroundStyle(.blue)
      .symbolSize(20)

      if let hoveredDate, point.date == hoveredDate {
        RuleMark(x: .value("Date", hoveredDate))
          .foregroundStyle(.secondary.opacity(0.5))
          .lineStyle(StrokeStyle(dash: [4, 4]))
          .annotation(position: .top, alignment: .center) {
            tooltipView(for: point)
          }
      }
    }
    .chartYAxis {
      AxisMarks { value in
        AxisGridLine()
        AxisValueLabel {
          if let val = value.as(Double.self) {
            Text(ChartDataService.abbreviatedLabel(for: val))
          }
        }
      }
    }
    .chartOverlay { proxy in
      GeometryReader { _ in
        Rectangle()
          .fill(.clear)
          .contentShape(Rectangle())
          .onContinuousHover { phase in
            switch phase {
            case .active(let location):
              hoveredDate = ChartHelpers.findNearestDate(
                at: location, in: proxy, points: points, dateKeyPath: \.date)

            case .ended:
              hoveredDate = nil
            }
          }
          .onTapGesture { location in
            if let date = ChartHelpers.findNearestDate(
              at: location, in: proxy, points: points, dateKeyPath: \.date)
            {
              onSelectSnapshot?(date)
            }
          }
      }
    }
    .frame(height: ChartConstants.dashboardChartHeight)
  }

  private func singlePointChart(_ points: [DashboardDataPoint]) -> some View {
    Chart(points, id: \.date) { point in
      PointMark(
        x: .value("Date", point.date),
        y: .value("Value", point.value.doubleValue)
      )
      .foregroundStyle(.blue)
    }
    .chartYAxis {
      AxisMarks { value in
        AxisGridLine()
        AxisValueLabel {
          if let val = value.as(Double.self) {
            Text(ChartDataService.abbreviatedLabel(for: val))
          }
        }
      }
    }
    .frame(height: ChartConstants.dashboardChartHeight)
  }

  private func emptyMessage(_ text: String) -> some View {
    ChartEmptyMessage(text: text, height: ChartConstants.dashboardChartHeight)
  }

  private func tooltipView(for point: DashboardDataPoint) -> some View {
    ChartTooltipView {
      Text(point.date.formatted(date: .abbreviated, time: .omitted))
        .font(.caption2)
      Text(point.value.formatted(currency: SettingsService.shared.mainCurrency))
        .font(.caption.bold())
    }
  }
}
