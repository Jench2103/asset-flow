//
//  CategoryValueLineChart.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Charts
import SwiftUI

/// Multi-category value history line chart (SPEC 12.3).
///
/// Displays one line per category with a legend toggle to show/hide categories.
/// No click-to-navigate behavior per SPEC 12.3.
struct CategoryValueLineChart: View {
  let categoryHistory: [String: [DashboardDataPoint]]
  @Binding var timeRange: ChartTimeRange

  @State private var disabledCategories: Set<String> = []
  @State private var hoveredDate: Date?

  /// Category names sorted alphabetically, with Uncategorized last.
  private var sortedCategoryNames: [String] {
    let names = Array(categoryHistory.keys)
    return names.sorted { lhs, rhs in
      if lhs == "Uncategorized" { return false }
      if rhs == "Uncategorized" { return true }
      return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
    }
  }

  /// Whether a category has all-zero values (should be omitted from chart).
  private func hasData(_ categoryName: String) -> Bool {
    guard let points = categoryHistory[categoryName] else { return false }
    return points.contains { $0.value != 0 }
  }

  /// Flattened and filtered data points for the chart.
  private var chartData: [CategoryChartPoint] {
    var result: [CategoryChartPoint] = []
    for name in sortedCategoryNames {
      guard !disabledCategories.contains(name), hasData(name) else { continue }
      guard let points = categoryHistory[name] else { continue }
      let filtered = ChartDataService.filter(points, range: timeRange)
      for point in filtered {
        result.append(
          CategoryChartPoint(
            date: point.date, value: point.value, categoryName: name))
      }
    }
    return result
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Category Value History")
        .font(.headline)

      ChartTimeRangeSelector(selection: $timeRange)

      if categoryHistory.isEmpty {
        emptyMessage("Create categories to see allocation trends")
      } else {
        chartWithLegend
      }
    }
    .padding()
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .background(.fill.quaternary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private var chartWithLegend: some View {
    VStack(alignment: .leading, spacing: 8) {
      let data = chartData
      if data.isEmpty {
        emptyMessage("No data for selected period")
      } else {
        Chart(data, id: \.id) { point in
          LineMark(
            x: .value("Date", point.date),
            y: .value("Value", point.value.doubleValue)
          )
          .foregroundStyle(by: .value("Category", point.categoryName))

          PointMark(
            x: .value("Date", point.date),
            y: .value("Value", point.value.doubleValue)
          )
          .foregroundStyle(by: .value("Category", point.categoryName))
          .symbolSize(15)

          if let hoveredDate, point.date == hoveredDate {
            RuleMark(x: .value("Date", hoveredDate))
              .foregroundStyle(.secondary.opacity(0.5))
              .lineStyle(StrokeStyle(dash: [4, 4]))
          }
        }
        .chartForegroundStyleScale(
          domain: enabledCategoryNames,
          range: enabledCategoryNames.map { colorForCategory($0) }
        )
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
        .chartLegend(.hidden)
        .chartOverlay { proxy in
          GeometryReader { _ in
            Rectangle()
              .fill(.clear)
              .contentShape(Rectangle())
              .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                  hoveredDate = ChartHelpers.findNearestDate(
                    at: location, in: proxy, points: data, dateKeyPath: \.date)

                case .ended:
                  hoveredDate = nil
                }
              }
          }
        }
        .overlay(alignment: .top) {
          if let hoveredDate {
            categoryTooltipView(for: hoveredDate, data: data)
          }
        }
        .frame(height: ChartConstants.dashboardChartHeight)
      }

      legendView
    }
  }

  /// Category names that are enabled (not disabled) and have data — used for chart color scale.
  private var enabledCategoryNames: [String] {
    sortedCategoryNames.filter { !disabledCategories.contains($0) && hasData($0) }
  }

  private var legendView: some View {
    FlowLayout(spacing: 6) {
      ForEach(sortedCategoryNames, id: \.self) { name in
        legendItem(for: name)
      }
    }
  }

  private func legendItem(for name: String) -> some View {
    let isDisabled = disabledCategories.contains(name)
    let noData = !hasData(name)

    return Button {
      if disabledCategories.contains(name) {
        disabledCategories.remove(name)
      } else {
        disabledCategories.insert(name)
      }
    } label: {
      HStack(spacing: 4) {
        Circle()
          .fill(isDisabled ? .gray.opacity(0.3) : colorForCategory(name))
          .frame(width: 8, height: 8)
        Text(name)
          .font(.caption2)
          .strikethrough(isDisabled)
        if noData {
          Text("(no data)")
            .font(.caption2)
            .foregroundStyle(.tertiary)
        }
      }
      .foregroundStyle(isDisabled ? .secondary : .primary)
    }
    .buttonStyle(.plain)
    .disabled(noData)
  }

  private func categoryTooltipView(
    for date: Date, data: [CategoryChartPoint]
  ) -> some View {
    let pointsAtDate = data.filter { $0.date == date }
    return ChartTooltipView {
      Text(date.settingsFormatted())
        .font(.caption2)
      ForEach(pointsAtDate, id: \.categoryName) { point in
        HStack(spacing: 4) {
          Circle()
            .fill(colorForCategory(point.categoryName))
            .frame(width: 6, height: 6)
          Text(point.categoryName)
            .font(.caption2)
          Spacer()
          Text(point.value.formatted(currency: SettingsService.shared.mainCurrency))
            .font(.caption2.bold())
        }
      }
    }
  }

  private func emptyMessage(_ text: String) -> some View {
    ChartEmptyMessage(text: text, height: ChartConstants.dashboardChartHeight)
  }

  private func colorForCategory(_ name: String) -> Color {
    if name == "Uncategorized" { return .gray }
    let index =
      sortedCategoryNames.filter { $0 != "Uncategorized" }
      .firstIndex(of: name) ?? 0
    return ChartConstants.color(forIndex: index)
  }
}

/// Data point for multi-category chart, including category name for color coding.
private struct CategoryChartPoint: Identifiable {
  var id: String { "\(categoryName)-\(date.timeIntervalSince1970)" }
  let date: Date
  let value: Decimal
  let categoryName: String
}

/// Simple flow layout for legend items that wraps to next line.
private struct FlowLayout: Layout {
  var spacing: CGFloat = 6

  func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
    let result = layout(in: proposal.width ?? 0, subviews: subviews)
    return result.size
  }

  func placeSubviews(
    in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()
  ) {
    let result = layout(in: bounds.width, subviews: subviews)
    for (index, position) in result.positions.enumerated() {
      subviews[index].place(
        at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
        proposal: ProposedViewSize(subviews[index].sizeThatFits(.unspecified)))
    }
  }

  private struct LayoutResult {
    var positions: [CGPoint]
    var size: CGSize
  }

  private func layout(in maxWidth: CGFloat, subviews: Subviews) -> LayoutResult {
    var positions: [CGPoint] = []
    var currentX: CGFloat = 0
    var currentY: CGFloat = 0
    var rowHeight: CGFloat = 0
    var maxX: CGFloat = 0

    for subview in subviews {
      let size = subview.sizeThatFits(.unspecified)
      if currentX + size.width > maxWidth, currentX > 0 {
        currentX = 0
        currentY += rowHeight + spacing
        rowHeight = 0
      }
      positions.append(CGPoint(x: currentX, y: currentY))
      rowHeight = max(rowHeight, size.height)
      currentX += size.width + spacing
      maxX = max(maxX, currentX)
    }

    return LayoutResult(
      positions: positions,
      size: CGSize(width: maxX, height: currentY + rowHeight))
  }
}
