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
  @State private var contentWidth: CGFloat = 400
  @State private var legendItemWidth: CGFloat = 120

  /// Chart data with zero-fill entries for disappearing categories, ensuring
  /// SectorMark identity is stable so Swift Charts interpolates angles.
  /// Entries are never removed — zero-angle marks are invisible and the total
  /// count is bounded by the unique categories across visited snapshots.
  @State private var chartData: [CategoryAllocationData] = []

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
    .glassCard()
    .accessibilityLabel("Category allocation pie chart")
    .onAppear {
      chartData = allocations
    }
    .onChange(of: allocations) { _, newAllocations in
      transitionChartData(to: newAllocations)
    }
  }

  /// Transitions chart data with zero-fill so SectorMark count never changes
  /// during animation. The legend and layout update instantly from `allocations`;
  /// only the chart angle interpolation is animated.
  private func transitionChartData(to newAllocations: [CategoryAllocationData]) {
    let oldNames = Set(chartData.map(\.categoryName))
    let newNames = Set(newAllocations.map(\.categoryName))

    // Pre-insert appearing categories at zero angle (no animation).
    for name in newNames.subtracting(oldNames) {
      chartData.append(CategoryAllocationData(categoryName: name, value: 0, percentage: 0))
    }

    // Build target: real values for current categories, zero for absent ones.
    var target = newAllocations
    for name in oldNames.subtracting(newNames) {
      target.append(CategoryAllocationData(categoryName: name, value: 0, percentage: 0))
    }

    // Only chart angle changes are animated; legend/layout update instantly.
    withAnimation {
      chartData = target
    }
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
        .frame(
          width: ChartConstants.dashboardChartHeight,
          height: ChartConstants.dashboardChartHeight
        )
        .frame(maxWidth: .infinity)
      legendPanel
        .frame(width: legendGridMaxWidth)
    }
    .frame(height: ChartConstants.dashboardChartHeight)
    .onGeometryChange(for: CGFloat.self) { proxy in
      proxy.size.width
    } action: { width in
      contentWidth = width
    }
    .background {
      // Invisible view to measure the natural width of the widest legend item.
      VStack(alignment: .leading, spacing: 0) {
        ForEach(allocations, id: \.categoryName) { allocation in
          legendItemLabel(allocation)
        }
      }
      .fixedSize()
      .hidden()
      .onGeometryChange(for: CGFloat.self) { proxy in
        proxy.size.width
      } action: { width in
        legendItemWidth = min(width, 180)
      }
    }
  }

  /// The effective data for the Chart — uses chartData (with zero-fill) when available,
  /// falling back to allocations on first render before onAppear fires.
  private var effectiveChartData: [CategoryAllocationData] {
    chartData.isEmpty ? allocations : chartData
  }

  private var chartView: some View {
    Chart(effectiveChartData, id: \.categoryName) { allocation in
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
          .onContinuousHoverWhenUnlocked { phase in
            switch phase {
            case .active(let location):
              let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
              let dx = location.x - center.x
              let dy = location.y - center.y
              // Convert to angle in degrees (0° at top, clockwise)
              var angle = atan2(dx, -dy) * 180 / .pi
              if angle < 0 { angle += 360 }
              // Map angle to cumulative value
              let angleValue = (angle / 360) * totalAllocatedValue
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

  private static let legendColumnSpacing: CGFloat = 12
  private static let legendHorizontalPadding: CGFloat = 8

  private var legendPanel: some View {
    ScrollView(.vertical, showsIndicators: true) {
      LazyVGrid(
        columns: Array(
          repeating: GridItem(
            .flexible(), spacing: Self.legendColumnSpacing, alignment: .topLeading),
          count: legendColumnCount),
        alignment: .leading,
        spacing: 4
      ) {
        ForEach(allocations, id: \.categoryName) { allocation in
          legendItem(allocation)
        }
      }
      .padding(.horizontal, Self.legendHorizontalPadding)
    }
  }

  /// Available width for legend columns, after subtracting the chart, HStack spacing, and legend padding.
  private var legendAvailableWidth: CGFloat {
    contentWidth - ChartConstants.dashboardChartHeight - 12 - Self.legendHorizontalPadding * 2
  }

  /// Width for the legend panel including grid columns, inter-column spacing, and horizontal padding.
  private var legendGridMaxWidth: CGFloat {
    let count = CGFloat(legendColumnCount)
    let gridWidth = count * legendItemWidth + max(0, count - 1) * Self.legendColumnSpacing
    return gridWidth + Self.legendHorizontalPadding * 2
  }

  private func legendItem(_ allocation: CategoryAllocationData) -> some View {
    Button {
      if allocation.categoryName != "Uncategorized" {
        onSelectCategory?(allocation.categoryName)
      }
    } label: {
      legendItemLabel(allocation)
    }
    .buttonStyle(.plain)
    .opacity(
      hoveredCategory == nil || hoveredCategory == allocation.categoryName
        ? 1.0 : 0.5
    )
    .onHoverWhenUnlocked { isHovering in
      hoveredCategory = isHovering ? allocation.categoryName : nil
    }
  }

  private func legendItemLabel(_ allocation: CategoryAllocationData) -> some View {
    HStack(spacing: 4) {
      Circle()
        .fill(colorForCategory(allocation.categoryName))
        .frame(width: 8, height: 8)
        .fixedSize()
      VStack(alignment: .leading, spacing: 0) {
        Text(allocation.categoryName)
          .font(.caption2)
          .lineLimit(1)
        Text(allocation.percentage.formattedPercentage())
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }

  /// Computes the fewest legend columns needed to display all categories without scrolling,
  /// bounded by the available width.
  private var legendColumnCount: Int {
    let estimatedItemHeight: CGFloat = 30
    let maxRows = max(1, Int(ChartConstants.dashboardChartHeight / estimatedItemHeight))
    let neededColumns = max(1, (allocations.count + maxRows - 1) / maxRows)
    let maxColumns = max(1, Int(legendAvailableWidth / legendItemWidth))
    return min(neededColumns, maxColumns)
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

  private func emptyMessage(_ text: LocalizedStringKey) -> some View {
    ChartEmptyMessage(text: text, height: ChartConstants.dashboardChartHeight)
  }

  /// Total allocated value for angle-to-category mapping in hover callbacks.
  private var totalAllocatedValue: Double {
    allocations.reduce(0.0) { $0 + $1.value.doubleValue }
  }

  /// Category name → color dictionary based on all known categories (from
  /// `effectiveChartData`). Since `chartData` never drops entries, each category
  /// keeps a stable color across date transitions — no color snap during animation.
  private var categoryColorMap: [String: Color] {
    var map: [String: Color] = ["Uncategorized": .gray]
    let sorted =
      effectiveChartData
      .map(\.categoryName)
      .filter { $0 != "Uncategorized" }
      .sorted()
    for (index, name) in sorted.enumerated() {
      map[name] = ChartConstants.color(forIndex: index)
    }
    return map
  }

  private func colorForCategory(_ name: String) -> Color {
    categoryColorMap[name] ?? .gray
  }
}
