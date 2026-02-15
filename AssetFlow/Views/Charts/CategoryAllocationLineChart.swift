//
//  CategoryAllocationLineChart.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Charts
import SwiftUI

/// Single-category allocation percentage line chart for CategoryDetailView.
///
/// Shows allocation % over time with a green line and Y-axis from 0-100%.
/// Includes time range selector and hover tooltip.
struct CategoryAllocationLineChart: View {
  let entries: [CategoryAllocationHistoryEntry]
  @Binding var timeRange: ChartTimeRange

  @State private var hoveredDate: Date?

  private var filteredEntries: [CategoryAllocationHistoryEntry] {
    ChartDataService.filter(entries, range: timeRange)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ChartTimeRangeSelector(selection: $timeRange)

      chartContent
    }
  }

  @ViewBuilder
  private var chartContent: some View {
    let points = filteredEntries
    if entries.isEmpty {
      emptyMessage("No allocation history")
    } else if points.isEmpty {
      emptyMessage("No data for selected period")
    } else if points.count == 1 {
      singlePointChart(points)
    } else {
      lineChart(points)
    }
  }

  private func lineChart(_ points: [CategoryAllocationHistoryEntry]) -> some View {
    Chart(points) { entry in
      LineMark(
        x: .value("Date", entry.date),
        y: .value("Allocation", entry.allocationPercentage.doubleValue)
      )
      .foregroundStyle(.green)

      PointMark(
        x: .value("Date", entry.date),
        y: .value("Allocation", entry.allocationPercentage.doubleValue)
      )
      .foregroundStyle(.green)

      if let hoveredDate, entry.date == hoveredDate {
        RuleMark(x: .value("Date", hoveredDate))
          .foregroundStyle(.secondary.opacity(0.5))
          .lineStyle(StrokeStyle(dash: [4, 4]))
          .annotation(position: .top, alignment: .center) {
            tooltipView(for: entry)
          }
      }
    }
    .chartYScale(domain: 0...100)
    .chartYAxis {
      AxisMarks { value in
        AxisGridLine()
        AxisValueLabel {
          if let val = value.as(Double.self) {
            Text(Decimal(Int(val.rounded())).formattedPercentage())
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
    .frame(height: ChartConstants.standardChartHeight)
  }

  private func singlePointChart(_ points: [CategoryAllocationHistoryEntry]) -> some View {
    Chart(points) { entry in
      PointMark(
        x: .value("Date", entry.date),
        y: .value("Allocation", entry.allocationPercentage.doubleValue)
      )
      .foregroundStyle(.green)
    }
    .chartYScale(domain: 0...100)
    .chartYAxis {
      AxisMarks { value in
        AxisGridLine()
        AxisValueLabel {
          if let val = value.as(Double.self) {
            Text(Decimal(Int(val.rounded())).formattedPercentage())
          }
        }
      }
    }
    .frame(height: ChartConstants.standardChartHeight)
  }

  private func emptyMessage(_ text: String) -> some View {
    ChartEmptyMessage(text: text, height: ChartConstants.standardChartHeight)
  }

  private func tooltipView(for entry: CategoryAllocationHistoryEntry) -> some View {
    ChartTooltipView {
      Text(entry.date.settingsFormatted())
        .font(.caption2)
      Text(entry.allocationPercentage.formattedPercentage())
        .font(.caption.bold())
    }
  }
}
