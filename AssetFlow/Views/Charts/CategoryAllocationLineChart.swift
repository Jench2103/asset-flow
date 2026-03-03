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
/// Shows allocation % over time with a green line and a smart dynamic Y-axis.
/// When a target allocation is set, displays a dashed orange reference line.
/// Includes time range selector and hover tooltip.
struct CategoryAllocationLineChart: View {
  let entries: [CategoryAllocationHistoryEntry]
  @Binding var timeRange: ChartTimeRange
  let targetAllocationPercentage: Decimal?

  @State private var hoveredDate: Date?

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
    } else if points.count == 1 {
      singlePointChart(points)
    } else {
      lineChart(points)
    }
  }

  private func lineChart(_ points: [CategoryAllocationHistoryEntry]) -> some View {
    let firstDate = points.first!.date
    let lastDate = points.last!.date
    let (yMin, yMax) = yAxisDomain(for: points)
    return Chart {
      targetRuleMark()

      ForEach(points) { entry in
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
            .annotation(
              position: .top,
              alignment: entry.date == firstDate
                ? .leading
                : entry.date == lastDate ? .trailing : .center
            ) {
              tooltipView(for: entry)
            }
        }
      }
    }
    .chartXScale(domain: firstDate...lastDate)
    .chartYScale(domain: yMin...yMax)
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
          .onContinuousHoverWhenUnlocked { phase in
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
    let (yMin, yMax) = yAxisDomain(for: points)
    return Chart {
      targetRuleMark()

      ForEach(points) { entry in
        PointMark(
          x: .value("Date", entry.date),
          y: .value("Allocation", entry.allocationPercentage.doubleValue)
        )
        .foregroundStyle(.green)
      }
    }
    .chartYScale(domain: yMin...yMax)
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

  @ChartContentBuilder
  private func targetRuleMark() -> some ChartContent {
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

  private func yAxisDomain(for points: [CategoryAllocationHistoryEntry]) -> (Double, Double) {
    let yValues = points.map { $0.allocationPercentage.doubleValue }
    var dataMin = yValues.min()!
    var dataMax = yValues.max()!
    if let target = targetAllocationPercentage?.doubleValue {
      dataMin = min(dataMin, target)
      dataMax = max(dataMax, target)
    }
    if dataMin == dataMax {
      dataMin = max(0, dataMin - 5)
      dataMax = min(100, dataMax + 5)
    }
    return (dataMin, dataMax)
  }

  private func emptyMessage(_ text: LocalizedStringKey) -> some View {
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
