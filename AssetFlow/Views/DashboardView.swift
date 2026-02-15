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

  var onNavigateToSnapshots: (() -> Void)?
  var onNavigateToImport: (() -> Void)?
  var onSelectSnapshot: ((Date) -> Void)?
  var onNavigateToCategory: ((String) -> Void)?

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
    VStack(spacing: 16) {
      Spacer()
      Image(systemName: "chart.bar")
        .font(.system(size: 48))
        .foregroundStyle(.secondary)
      Text("Welcome to AssetFlow")
        .font(.title2)
      Text("Start tracking your portfolio by importing CSV data or creating a snapshot.")
        .font(.callout)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 40)
      Button("Import your first CSV") {
        onNavigateToImport?()
      }
      .buttonStyle(.borderedProminent)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150, maximum: 220))], spacing: 12) {
      MetricCard(
        title: "Total Portfolio Value",
        value: viewModel.totalPortfolioValue.formatted(
          currency: SettingsService.shared.mainCurrency),
        subtitle: valueChangeSubtitle
      )

      MetricCard(
        title: "Latest Snapshot",
        value: viewModel.latestSnapshotDate?.formatted(date: .abbreviated, time: .omitted)
          ?? "\u{2014}",
        subtitle: nil
      )

      MetricCard(
        title: "Assets",
        value: "\(viewModel.assetCount)",
        subtitle: nil
      )

      MetricCard(
        title: "Cumulative TWR",
        value: viewModel.cumulativeTWR?.formattedPercentage() ?? "N/A",
        subtitle: nil,
        showInfoIcon: true
      )

      MetricCard(
        title: "CAGR",
        value: viewModel.cagr?.formattedPercentage() ?? "N/A",
        subtitle: nil,
        showInfoIcon: true
      )
    }
  }

  private var valueChangeSubtitle: String? {
    guard let absolute = viewModel.valueChangeAbsolute,
      let percentage = viewModel.valueChangePercentage
    else { return nil }
    let sign = absolute >= 0 ? "+" : ""
    let currency = SettingsService.shared.mainCurrency
    return "\(sign)\(absolute.formatted(currency: currency)) (\(percentage.formattedPercentage()))"
  }

  // MARK: - Period Performance

  private var periodPerformanceRow: some View {
    HStack(spacing: 12) {
      // Growth Rate card
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Growth Rate")
            .font(.caption)
            .foregroundStyle(.secondary)
          Image(systemName: "info.circle")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .help("Details available in a future update")
        }

        Picker("Period", selection: $growthRatePeriod) {
          Text("1M").tag(DashboardPeriod.oneMonth)
          Text("3M").tag(DashboardPeriod.threeMonths)
          Text("1Y").tag(DashboardPeriod.oneYear)
        }
        .pickerStyle(.segmented)

        Text(viewModel.growthRate(for: growthRatePeriod)?.formattedPercentage() ?? "N/A")
          .font(.title3.bold())
          .monospacedDigit()
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.fill.quaternary)
      .clipShape(RoundedRectangle(cornerRadius: 8))

      // Return Rate card
      VStack(alignment: .leading, spacing: 8) {
        HStack {
          Text("Return Rate")
            .font(.caption)
            .foregroundStyle(.secondary)
          Image(systemName: "info.circle")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .help("Details available in a future update")
        }

        Picker("Period", selection: $returnRatePeriod) {
          Text("1M").tag(DashboardPeriod.oneMonth)
          Text("3M").tag(DashboardPeriod.threeMonths)
          Text("1Y").tag(DashboardPeriod.oneYear)
        }
        .pickerStyle(.segmented)

        Text(viewModel.returnRate(for: returnRatePeriod)?.formattedPercentage() ?? "N/A")
          .font(.title3.bold())
          .monospacedDigit()
      }
      .padding()
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(.fill.quaternary)
      .clipShape(RoundedRectangle(cornerRadius: 8))
    }
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
              Text(snapshot.date.formatted(date: .abbreviated, time: .omitted))
                .font(.body)

              Spacer()

              Text(
                snapshot.compositeTotal.formatted(currency: SettingsService.shared.mainCurrency)
              )
              .font(.body)
              .monospacedDigit()

              Text("\(snapshot.assetCount)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.quaternary)
                .clipShape(Capsule())
                .accessibilityLabel("\(snapshot.assetCount) assets")
            }
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)

          if snapshot.date != viewModel.recentSnapshots.last?.date {
            Divider()
          }
        }
      }
    }
    .padding()
    .background(.fill.quaternary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
  }
}

// MARK: - MetricCard

private struct MetricCard: View {
  let title: String
  let value: String
  var subtitle: String?
  var showInfoIcon: Bool = false

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack(spacing: 4) {
        Text(title)
          .font(.caption)
          .foregroundStyle(.secondary)
        if showInfoIcon {
          Image(systemName: "info.circle")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .help("Details available in a future update")
        }
      }

      Text(value)
        .font(.title3.bold())
        .monospacedDigit()
        .lineLimit(1)

      if let subtitle = subtitle {
        Text(subtitle)
          .font(.caption2)
          .foregroundStyle(.secondary)
          .lineLimit(1)
      }
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.fill.quaternary)
    .clipShape(RoundedRectangle(cornerRadius: 8))
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
