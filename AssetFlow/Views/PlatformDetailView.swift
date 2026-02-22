//
//  PlatformDetailView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/17.
//

import Charts
import SwiftData
import SwiftUI

/// Platform detail view for editing the platform name and viewing assets and value history.
///
/// Shows an editable name field, a table of assets on this platform with their
/// latest values, and a value history chart across all snapshots.
///
/// **Important:** The parent view must apply `.id(platform)` to this view
/// to force view recreation when the selected platform changes (e.g., after rename),
/// because `@State` ViewModel initialization only runs on first view creation.
struct PlatformDetailView: View {
  @State private var viewModel: PlatformDetailViewModel

  @State private var showSaveError = false
  @State private var saveErrorMessage = ""
  @State private var valueChartRange: ChartTimeRange = .all
  @State private var hoveredValueDate: Date?

  let onRename: (String) -> Void

  init(platformName: String, modelContext: ModelContext, onRename: @escaping (String) -> Void) {
    _viewModel = State(
      wrappedValue: PlatformDetailViewModel(platformName: platformName, modelContext: modelContext))
    self.onRename = onRename
  }

  var body: some View {
    Form {
      platformDetailsSection
      assetsSection
      valueHistorySection
    }
    .formStyle(.grouped)
    .navigationTitle(viewModel.platformName)
    .onAppear {
      viewModel.loadData()
    }
    .alert("Save Error", isPresented: $showSaveError) {
      Button("OK") {}
    } message: {
      Text(saveErrorMessage)
    }
  }

  // MARK: - Platform Details Section

  private var platformDetailsSection: some View {
    Section {
      TextField("Name", text: $viewModel.editedName)
        .onSubmit { saveChanges() }
        .accessibilityIdentifier("Platform Name Field")
    } header: {
      Text("Platform Details")
    }
  }

  // MARK: - Assets Section

  private var assetsSection: some View {
    Section {
      if viewModel.assets.isEmpty {
        Text("No assets on this platform")
          .foregroundStyle(.secondary)
      } else {
        Table(viewModel.assets) {
          TableColumn("Name") { row in
            Text(row.asset.name)
          }
          TableColumn("Category") { row in
            if let category = row.asset.category {
              Text(category.name)
            } else {
              Text("\u{2014}")
                .foregroundStyle(.secondary)
            }
          }
          TableColumn("Original Value") { row in
            if let value = row.latestValue {
              let effectiveCurrency =
                row.asset.currency.isEmpty
                ? SettingsService.shared.mainCurrency : row.asset.currency
              HStack(spacing: 4) {
                if effectiveCurrency != SettingsService.shared.mainCurrency {
                  Text(effectiveCurrency.uppercased())
                    .font(.caption2)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
                }
                Text(value.formatted(currency: effectiveCurrency))
                  .monospacedDigit()
              }
            } else {
              Text("\u{2014}")
                .foregroundStyle(.secondary)
            }
          }
          .alignment(.trailing)
          TableColumn("Converted Value") { row in
            if let converted = row.convertedValue {
              Text(converted.formatted(currency: SettingsService.shared.mainCurrency))
                .monospacedDigit()
            } else {
              Text("\u{2014}")
                .foregroundStyle(.secondary)
            }
          }
          .alignment(.trailing)
        }
        .frame(minHeight: 100)
      }
    } header: {
      Text("Assets on Platform")
    }
  }

  // MARK: - Value History Section

  private var filteredValueHistory: [PlatformValueHistoryEntry] {
    ChartDataService.filter(viewModel.valueHistory, range: valueChartRange)
  }

  private var valueHistorySection: some View {
    Section {
      ChartTimeRangeSelector(selection: $valueChartRange)

      let points = filteredValueHistory
      if viewModel.valueHistory.isEmpty {
        Text("No value history")
          .foregroundStyle(.secondary)
      } else if points.isEmpty {
        Text("No data for selected period")
          .foregroundStyle(.secondary)
      } else if points.count == 1 {
        singlePointValueChart(points)
      } else {
        valueLineChart(points)
      }
    } header: {
      Text("Value History")
    }
  }

  private func valueLineChart(_ points: [PlatformValueHistoryEntry]) -> some View {
    let firstDate = points.first!.date
    let lastDate = points.last!.date
    let yValues = points.map { $0.totalValue.doubleValue }
    let yMin = yValues.min()!
    let yMax = yValues.max()!
    return Chart(points) { entry in
      LineMark(
        x: .value("Date", entry.date),
        y: .value("Value", entry.totalValue.doubleValue)
      )
      .foregroundStyle(.blue)
      PointMark(
        x: .value("Date", entry.date),
        y: .value("Value", entry.totalValue.doubleValue)
      )
      .foregroundStyle(.blue)

      if let hoveredValueDate, entry.date == hoveredValueDate {
        RuleMark(x: .value("Date", hoveredValueDate))
          .foregroundStyle(.secondary.opacity(0.5))
          .lineStyle(StrokeStyle(dash: [4, 4]))
          .annotation(
            position: .top,
            alignment: entry.date == firstDate
              ? .leading
              : entry.date == lastDate ? .trailing : .center
          ) {
            ChartTooltipView {
              Text(entry.date.settingsFormatted())
                .font(.caption2)
              Text(entry.totalValue.formatted(currency: SettingsService.shared.mainCurrency))
                .font(.caption.bold())
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
              hoveredValueDate = ChartHelpers.findNearestDate(
                at: location, in: proxy, points: points, dateKeyPath: \.date)

            case .ended:
              hoveredValueDate = nil
            }
          }
      }
    }
    .frame(height: ChartConstants.standardChartHeight)
  }

  private func singlePointValueChart(_ points: [PlatformValueHistoryEntry]) -> some View {
    Chart(points) { entry in
      PointMark(
        x: .value("Date", entry.date),
        y: .value("Value", entry.totalValue.doubleValue)
      )
      .foregroundStyle(.blue)
    }
    .frame(height: ChartConstants.standardChartHeight)
  }

  // MARK: - Actions

  private func saveChanges() {
    let oldName = viewModel.platformName
    do {
      try viewModel.save()
      if viewModel.platformName != oldName {
        onRename(viewModel.platformName)
      }
    } catch {
      saveErrorMessage = error.localizedDescription
      showSaveError = true
    }
  }
}

// MARK: - Previews

#Preview("Platform Detail") {
  NavigationStack {
    PlatformDetailView(
      platformName: "Firstrade",
      modelContext: PreviewContainer.container.mainContext
    ) { _ in }
  }
}
