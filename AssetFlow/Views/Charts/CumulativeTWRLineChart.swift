//
//  CumulativeTWRLineChart.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
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

  @State private var hoveredDate: Date?

  private var filteredPoints: [DashboardDataPoint] {
    ChartDataService.filter(dataPoints, range: timeRange)
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
  }

  @ViewBuilder
  private var chartContent: some View {
    let points = filteredPoints
    if totalSnapshotCount < 2 {
      emptyMessage("Insufficient data (need at least 2 snapshots)")
    } else if points.isEmpty {
      emptyMessage("Cannot calculate returns for selected period")
    } else if points.count == 1 {
      singlePointChart(points)
    } else {
      lineChart(points)
    }
  }

  private func lineChart(_ points: [DashboardDataPoint]) -> some View {
    let firstDate = points.first!.date
    let lastDate = points.last!.date
    return Chart(points, id: \.date) { point in
      LineMark(
        x: .value("Date", point.date),
        y: .value("TWR", point.value.doubleValue * 100)
      )
      .foregroundStyle(.orange)

      PointMark(
        x: .value("Date", point.date),
        y: .value("TWR", point.value.doubleValue * 100)
      )
      .foregroundStyle(.orange)
      .symbolSize(20)

      if let hoveredDate, point.date == hoveredDate {
        RuleMark(x: .value("Date", hoveredDate))
          .foregroundStyle(.secondary.opacity(0.5))
          .lineStyle(StrokeStyle(dash: [4, 4]))
          .annotation(
            position: .top,
            alignment: point.date == firstDate
              ? .leading
              : point.date == lastDate ? .trailing : .center
          ) {
            tooltipView(for: point)
          }
      }
    }
    .chartXScale(domain: firstDate...lastDate)
    .chartYAxis {
      AxisMarks { value in
        AxisGridLine()
        AxisValueLabel {
          if let val = value.as(Double.self) {
            Text(Decimal(val).formattedPercentage())
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
      }
    }
    .frame(height: ChartConstants.dashboardChartHeight)
  }

  private func singlePointChart(_ points: [DashboardDataPoint]) -> some View {
    Chart(points, id: \.date) { point in
      PointMark(
        x: .value("Date", point.date),
        y: .value("TWR", point.value.doubleValue * 100)
      )
      .foregroundStyle(.orange)
    }
    .chartYAxis {
      AxisMarks { value in
        AxisGridLine()
        AxisValueLabel {
          if let val = value.as(Double.self) {
            Text(Decimal(val).formattedPercentage())
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
      Text(point.date.settingsFormatted())
        .font(.caption2)
      Text((point.value * 100).formattedPercentage())
        .font(.caption.bold())
    }
  }
}
