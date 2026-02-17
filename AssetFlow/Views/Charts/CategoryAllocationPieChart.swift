//
//  CategoryAllocationPieChart.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Charts
import SwiftUI

/// Category allocation pie chart with snapshot date picker (SPEC 12.1).
///
/// Uses SectorMark for pie slices, sorted by value (largest first).
/// Labels show category name, percentage, and value.
/// Click navigates to category detail and selects the category in sidebar.
struct CategoryAllocationPieChart: View {
  let allocations: [CategoryAllocationData]
  let snapshotDates: [Date]
  @Binding var selectedDate: Date?
  var onSelectCategory: ((String) -> Void)?

  @State private var hoveredCategory: String?
  @State private var selectedAngle: Double?

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Category Allocation")
          .font(.headline)
        Spacer()
        snapshotDatePicker
      }

      chartContent
    }
    .padding()
    .frame(maxHeight: .infinity, alignment: .topLeading)
    .background(.fill.quaternary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }

  private var snapshotDatePicker: some View {
    Picker("Snapshot", selection: $selectedDate) {
      Text("Latest").tag(Optional<Date>.none)
      ForEach(snapshotDates.reversed(), id: \.self) { date in
        Text(date.settingsFormatted())
          .tag(Optional(date))
      }
    }
    .frame(maxWidth: 180)
  }

  @ViewBuilder
  private var chartContent: some View {
    if allocations.isEmpty {
      emptyMessage("No asset data available")
    } else {
      pieChart
    }
  }

  private var pieChart: some View {
    HStack(alignment: .top, spacing: 12) {
      chartView
      legendPanel
    }
    .frame(height: ChartConstants.dashboardChartHeight)
  }

  private var chartView: some View {
    Chart(allocations, id: \.categoryName) { allocation in
      SectorMark(
        angle: .value("Value", allocation.value.doubleValue),
        innerRadius: .ratio(0.4),
        angularInset: 1.0
      )
      .foregroundStyle(colorForCategory(allocation.categoryName))
      .opacity(
        hoveredCategory == nil || hoveredCategory == allocation.categoryName ? 1.0 : 0.5)
    }
    .chartLegend(.hidden)
    .chartBackground { _ in
      // Center label for hovered category
      if let hoveredCategory,
        let allocation = allocations.first(where: { $0.categoryName == hoveredCategory })
      {
        VStack(spacing: 2) {
          Text(hoveredCategory)
            .font(.caption.bold())
          Text(allocation.percentage.formattedPercentage())
            .font(.caption2)
          Text(allocation.value.formatted(currency: SettingsService.shared.mainCurrency))
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
      }
    }
    .chartAngleSelection(value: $selectedAngle)
    .chartOverlay { _ in
      GeometryReader { geometry in
        Rectangle()
          .fill(.clear)
          .contentShape(Rectangle())
          .onContinuousHover { phase in
            switch phase {
            case .active(let location):
              let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
              let dx = location.x - center.x
              let dy = location.y - center.y
              // Convert to angle in degrees (0° at top, clockwise)
              var angle = atan2(dx, -dy) * 180 / .pi
              if angle < 0 { angle += 360 }
              // Map angle to cumulative value
              let totalValue = allocations.reduce(0.0) { $0 + $1.value.doubleValue }
              let angleValue = (angle / 360) * totalValue
              hoveredCategory = categoryAtAngleValue(angleValue)

            case .ended:
              hoveredCategory = nil
            }
          }
      }
    }
    .onChange(of: selectedAngle) { _, newValue in
      guard let newValue else { return }
      if let name = categoryAtAngleValue(newValue),
        name != "Uncategorized"
      {
        onSelectCategory?(name)
      }
    }
  }

  private var legendPanel: some View {
    ScrollView(.vertical, showsIndicators: false) {
      VStack(alignment: .leading, spacing: 4) {
        ForEach(allocations, id: \.categoryName) { allocation in
          Button {
            if allocation.categoryName != "Uncategorized" {
              onSelectCategory?(allocation.categoryName)
            }
          } label: {
            HStack(spacing: 4) {
              Circle()
                .fill(colorForCategory(allocation.categoryName))
                .frame(width: 8, height: 8)
                .fixedSize()
              VStack(alignment: .leading, spacing: 0) {
                Text(allocation.categoryName)
                  .font(.caption2)
                  .lineLimit(1)
                  .truncationMode(.tail)
                Text(allocation.percentage.formattedPercentage())
                  .font(.caption2)
                  .foregroundStyle(.secondary)
              }
            }
          }
          .buttonStyle(.plain)
          .opacity(
            hoveredCategory == nil || hoveredCategory == allocation.categoryName
              ? 1.0 : 0.5
          )
          .onHover { isHovering in
            hoveredCategory = isHovering ? allocation.categoryName : nil
          }
        }
      }
    }
    .frame(width: 150)
  }

  /// Maps a cumulative angle value to the category at that position in the pie chart.
  private func categoryAtAngleValue(_ value: Double) -> String? {
    var cumulative = 0.0
    for allocation in allocations {
      cumulative += allocation.value.doubleValue
      if value <= cumulative {
        return allocation.categoryName
      }
    }
    return allocations.last?.categoryName
  }

  private func emptyMessage(_ text: String) -> some View {
    ChartEmptyMessage(text: text, height: ChartConstants.dashboardChartHeight)
  }

  private func colorForCategory(_ name: String) -> Color {
    if name == "Uncategorized" {
      return .gray
    }
    let sortedNames = allocations.filter { $0.categoryName != "Uncategorized" }
      .map(\.categoryName)
    if let index = sortedNames.firstIndex(of: name) {
      return ChartConstants.color(forIndex: index)
    }
    return .gray
  }
}
