//
//  DashboardView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Charts
import SwiftData
import SwiftUI

/// Dashboard home screen with portfolio metrics, performance, and interactive charts.
///
/// Provides a high-level overview of the portfolio including total value,
/// value change, TWR, CAGR, period growth/return rates, interactive charts
/// (category allocation, portfolio value, cumulative TWR, category value history),
/// and recent snapshots.
struct DashboardView: View {
  @State private var viewModel: DashboardViewModel

  @State private var growthRatePeriod: DashboardPeriod = .oneMonth
  @State private var returnRatePeriod: DashboardPeriod = .oneMonth

  @State private var portfolioChartRange: ChartTimeRange = .all
  @State private var twrChartRange: ChartTimeRange = .all
  @State private var categoryChartRange: ChartTimeRange = .all
  @State private var pieChartSelectedDate: Date?

  let onNavigateToSnapshots: (() -> Void)?
  let onNavigateToImport: (() -> Void)?
  let onSelectSnapshot: ((Date) -> Void)?
  let onNavigateToCategory: ((String) -> Void)?

  init(
    modelContext: ModelContext,
    onNavigateToSnapshots: (() -> Void)? = nil,
    onNavigateToImport: (() -> Void)? = nil,
    onSelectSnapshot: ((Date) -> Void)? = nil,
    onNavigateToCategory: ((String) -> Void)? = nil
  ) {
    _viewModel = State(wrappedValue: DashboardViewModel(modelContext: modelContext))
    self.onNavigateToSnapshots = onNavigateToSnapshots
    self.onNavigateToImport = onNavigateToImport
    self.onSelectSnapshot = onSelectSnapshot
    self.onNavigateToCategory = onNavigateToCategory
  }

  var body: some View {
    Group {
      if viewModel.isEmpty {
        emptyState
      } else {
        dashboardContent
      }
    }
    .navigationTitle("Dashboard")
    .onAppear {
      viewModel.loadData()
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    ContentUnavailableView {
      Label("Welcome to AssetFlow", systemImage: "chart.bar")
    } description: {
      Text("Start tracking your portfolio by importing CSV data or creating a snapshot.")
    } actions: {
      Button("Import your first CSV") {
        onNavigateToImport?()
      }
      .buttonStyle(.borderedProminent)
    }
  }

  // MARK: - Dashboard Content

  private var dashboardContent: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 20) {
        summaryCardsRow
        periodPerformanceRow
        chartsSection
        recentSnapshotsSection
      }
      .padding()
    }
  }

  // MARK: - Summary Cards

  private var summaryCardsRow: some View {
    VStack(spacing: 12) {
      // Hero card: Total Portfolio Value
      HeroMetricCard(
        title: "Total Portfolio Value",
        value: viewModel.totalPortfolioValue.formatted(
          currency: SettingsService.shared.mainCurrency)
      )

      // Secondary metrics grid
      HStack(spacing: 12) {
        MetricCard(
          title: "Latest Snapshot",
          value: viewModel.latestSnapshotDate?.settingsFormatted()
            ?? "\u{2014}",
          subtitle: nil
        )

        MetricCard(
          title: "Assets",
          value: "\(viewModel.assetCount)",
          subtitle: nil
        )

        MetricCard(
          title: "Cumulative TWR (All Time)",
          value: viewModel.cumulativeTWR.map { ($0 * 100).formattedPercentage() } ?? "N/A",
          subtitle: nil,
          helpText:
            "Time-weighted return measures pure investment performance by removing the effect of external cash flows (deposits and withdrawals)."
        )

        MetricCard(
          title: "CAGR",
          value: viewModel.cagr.map { ($0 * 100).formattedPercentage() } ?? "N/A",
          subtitle: nil,
          helpText:
            "CAGR is the annualized rate at which the portfolio's total value has grown since inception, including the effect of deposits and withdrawals."
        )
      }
    }
  }

  private func rateColor(for value: Decimal?) -> Color {
    guard let value else { return .primary }
    if value > 0 { return .green }
    if value < 0 { return .red }
    return .primary
  }

  // MARK: - Period Performance

  private func dateRangeSubtitle(for period: DashboardPeriod) -> String? {
    guard let range = viewModel.periodDateRange(for: period) else { return nil }
    let beginStr = range.begin.settingsFormatted()
    let endStr = range.end.settingsFormatted()
    return "\(beginStr) – \(endStr)"
  }

  private var periodPerformanceRow: some View {
    HStack(spacing: 12) {
      // Growth Rate card
      HStack {
        VStack(alignment: .leading) {
          Text("Growth Rate")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
        }

        Spacer()

        let growthValue = viewModel.growthRate(for: growthRatePeriod)
        Text(growthValue.map { ($0 * 100).formattedPercentage() } ?? "N/A")
          .font(.title.bold())
          .monospacedDigit()
          .foregroundStyle(rateColor(for: growthValue))
          .contentTransition(.numericText())

        Spacer()

        VStack(alignment: .trailing) {
          periodPicker(selection: $growthRatePeriod)
          Spacer()
          if growthValue != nil, let subtitle = dateRangeSubtitle(for: growthRatePeriod) {
            Text(subtitle)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding()
      .frame(maxWidth: .infinity)
      .glassCard()
      .helpWhenUnlocked(
        LocalizedStringKey(
          "Growth rate is the simple percentage change in portfolio value over the selected period, including the effect of deposits and withdrawals."
        )
      )
      .animation(AnimationConstants.numericText, value: growthRatePeriod)

      // Return Rate card
      HStack {
        VStack(alignment: .leading) {
          Text("Return Rate")
            .font(.caption)
            .foregroundStyle(.secondary)
          Spacer()
        }

        Spacer()

        let returnValue = viewModel.returnRate(for: returnRatePeriod)
        Text(returnValue.map { ($0 * 100).formattedPercentage() } ?? "N/A")
          .font(.title.bold())
          .monospacedDigit()
          .foregroundStyle(rateColor(for: returnValue))
          .contentTransition(.numericText())

        Spacer()

        VStack(alignment: .trailing) {
          periodPicker(selection: $returnRatePeriod)
          Spacer()
          if returnValue != nil, let subtitle = dateRangeSubtitle(for: returnRatePeriod) {
            Text(subtitle)
              .font(.caption2)
              .foregroundStyle(.secondary)
          }
        }
      }
      .padding()
      .frame(maxWidth: .infinity)
      .glassCard()
      .helpWhenUnlocked(
        LocalizedStringKey(
          "Return rate uses the Modified Dietz method to calculate a cash-flow adjusted return, isolating actual investment performance."
        )
      )
      .animation(AnimationConstants.numericText, value: returnRatePeriod)
    }
  }

  private func periodPicker(selection: Binding<DashboardPeriod>) -> some View {
    Picker("Period", selection: selection) {
      Text("1M").tag(DashboardPeriod.oneMonth)
      Text("3M").tag(DashboardPeriod.threeMonths)
      Text("1Y").tag(DashboardPeriod.oneYear)
    }
    .pickerStyle(.segmented)
    .labelsHidden()
    .controlSize(.small)
    .fixedSize()
  }

  // MARK: - Charts Section

  private var pieChartAllocations: [CategoryAllocationData] {
    if let selectedDate = pieChartSelectedDate {
      return viewModel.categoryAllocations(forSnapshotDate: selectedDate)
    }
    return viewModel.categoryAllocations
  }

  private var chartsSection: some View {
    VStack(spacing: 12) {
      // Row 1: Pie chart + Portfolio value line chart
      HStack(alignment: .top, spacing: 12) {
        CategoryAllocationPieChart(
          allocations: pieChartAllocations,
          snapshotDates: viewModel.snapshotDates,
          selectedDate: $pieChartSelectedDate,
          onSelectCategory: { name in
            onNavigateToCategory?(name)
          }
        )

        PortfolioValueLineChart(
          dataPoints: viewModel.portfolioValueHistory,
          timeRange: $portfolioChartRange,
          onSelectSnapshot: { date in
            onSelectSnapshot?(date)
          }
        )
      }

      // Row 2: TWR line chart + Category value line chart
      HStack(alignment: .top, spacing: 12) {
        CumulativeTWRLineChart(
          dataPoints: viewModel.twrHistory,
          totalSnapshotCount: viewModel.portfolioValueHistory.count,
          timeRange: $twrChartRange
        )

        CategoryValueLineChart(
          categoryHistory: viewModel.categoryValueHistory,
          timeRange: $categoryChartRange
        )
      }
    }
  }

  // MARK: - Recent Snapshots

  private var recentSnapshotsSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Recent Snapshots")
          .font(.headline)
        Spacer()
        Button("View All") {
          onNavigateToSnapshots?()
        }
        .font(.callout)
        .helpWhenUnlocked("View all snapshots")
      }

      if viewModel.recentSnapshots.isEmpty {
        Text("No snapshots yet")
          .foregroundStyle(.secondary)
      } else {
        ForEach(viewModel.recentSnapshots, id: \.date) { snapshot in
          Button {
            onSelectSnapshot?(snapshot.date)
          } label: {
            HStack {
              Text(snapshot.date.settingsFormatted())
                .font(.body)

              Spacer()

              Text(
                snapshot.totalValue.formatted(currency: SettingsService.shared.mainCurrency)
              )
              .font(.body)
              .monospacedDigit()

              Text("\(snapshot.assetCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, ChartConstants.badgePaddingH)
                .padding(.vertical, ChartConstants.badgePaddingV)
                .background(.quaternary)
                .clipShape(Capsule())
                .accessibilityLabel("\(snapshot.assetCount) assets")
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
          }
          .buttonStyle(SnapshotRowButtonStyle())

          if snapshot.date != viewModel.recentSnapshots.last?.date {
            Divider()
          }
        }
      }
    }
    .padding()
    .glassCard()
  }
}

// MARK: - HeroMetricCard

private struct HeroMetricCard: View {
  let title: LocalizedStringKey
  let value: String

  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
        Spacer()
      }

      Spacer()

      Text(value)
        .font(.largeTitle.bold())
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.7)
        .contentTransition(.numericText())

      Spacer()
    }
    .padding()
    .frame(maxWidth: .infinity)
    .background {
      ZStack {
        Rectangle().fill(.ultraThinMaterial)
        Rectangle().fill(.tint.opacity(0.06))
      }
    }
    .clipShape(RoundedRectangle(cornerRadius: ChartConstants.cardCornerRadius))
    .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
    .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
    .overlay(
      RoundedRectangle(cornerRadius: ChartConstants.cardCornerRadius)
        .strokeBorder(.tint.opacity(0.15), lineWidth: 1)
    )
    .accessibilityElement(children: .combine)
  }
}

// MARK: - MetricCard

private struct MetricCard: View {
  let title: LocalizedStringKey
  let value: String
  var subtitle: String?
  var helpText: LocalizedStringKey?

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(title)
        .font(.caption)
        .foregroundStyle(.secondary)

      Spacer(minLength: 10)

      Text(value)
        .font(.title3.bold())
        .monospacedDigit()
        .lineLimit(1)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .contentTransition(.numericText())

      if let subtitle {
        Text(subtitle)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
          .frame(maxWidth: .infinity, alignment: .trailing)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, minHeight: 80)
    .glassCard()
    .accessibilityElement(children: .combine)
    .helpWhenUnlocked(helpText)
  }
}

// MARK: - SnapshotRowButtonStyle

private struct SnapshotRowButtonStyle: ButtonStyle {
  @State private var isHovered = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background(
        RoundedRectangle(cornerRadius: 4)
          .fill(isHovered ? Color.primary.opacity(0.06) : Color.clear)
      )
      .onHoverWhenUnlocked { hovering in
        isHovered = hovering
      }
  }
}

// MARK: - Previews

#Preview("Dashboard - Empty") {
  NavigationStack {
    DashboardView(
      modelContext: PreviewContainer.container.mainContext
    )
  }
}
