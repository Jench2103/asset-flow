//
//  CategoryDetailView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Charts
import SwiftData
import SwiftUI

/// Category detail view for editing properties and viewing history.
///
/// Shows editable fields (name, target allocation), assets in the category,
/// value and allocation history charts, and a delete action with validation.
///
/// **Important:** The parent view must apply `.id(category.id)` to this view
/// to force view recreation when the selected category changes, because `@State`
/// ViewModel initialization only runs on first view creation.
struct CategoryDetailView: View {
  @State private var viewModel: CategoryDetailViewModel

  @State private var showDeleteConfirmation = false
  @State private var showSaveError = false
  @State private var saveErrorMessage = ""
  @State private var valueChartRange: ChartTimeRange = .all
  @State private var allocationChartRange: ChartTimeRange = .all
  @State private var hoveredValueDate: Date?

  let onDelete: () -> Void

  init(category: Category, modelContext: ModelContext, onDelete: @escaping () -> Void) {
    _viewModel = State(
      wrappedValue: CategoryDetailViewModel(category: category, modelContext: modelContext))
    self.onDelete = onDelete
  }

  var body: some View {
    Form {
      categoryDetailsSection
      assetsSection
      valueHistorySection
      allocationHistorySection
      deleteSection
    }
    .formStyle(.grouped)
    .navigationTitle(viewModel.category.name)
    .onAppear {
      viewModel.loadData()
    }
    .alert("Save Error", isPresented: $showSaveError) {
      Button("OK") {}
    } message: {
      Text(saveErrorMessage)
    }
    .confirmationDialog(
      "Delete Category",
      isPresented: $showDeleteConfirmation
    ) {
      Button("Delete", role: .destructive) {
        viewModel.deleteCategory()
        onDelete()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "Are you sure you want to delete \"\(viewModel.category.name)\"? This action cannot be undone."
      )
    }
  }

  // MARK: - Category Details Section

  private var categoryDetailsSection: some View {
    Section {
      TextField("Name", text: $viewModel.editedName)
        .onSubmit { saveChanges() }
        .accessibilityIdentifier("Category Name Field")

      HStack {
        TextField("Target Allocation (e.g. 40)", text: $viewModel.targetAllocationText)
          .onSubmit { saveChanges() }
        Text("%")
          .foregroundStyle(.secondary)
      }
    } header: {
      Text("Category Details")
    }
  }

  // MARK: - Assets Section

  private var assetsSection: some View {
    Section {
      if viewModel.assets.isEmpty {
        Text("No assets in this category")
          .foregroundStyle(.secondary)
      } else {
        Table(viewModel.assets) {
          TableColumn("Name") { row in
            Text(row.asset.name)
          }
          TableColumn("Platform") { row in
            Text(row.asset.platform.isEmpty ? "\u{2014}" : row.asset.platform)
              .foregroundStyle(row.asset.platform.isEmpty ? .secondary : .primary)
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
      Text("Assets in Category")
    }
  }

  // MARK: - Value History Section

  private var filteredValueHistory: [CategoryValueHistoryEntry] {
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

  private func valueLineChart(_ points: [CategoryValueHistoryEntry]) -> some View {
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

  private func singlePointValueChart(_ points: [CategoryValueHistoryEntry]) -> some View {
    Chart(points) { entry in
      PointMark(
        x: .value("Date", entry.date),
        y: .value("Value", entry.totalValue.doubleValue)
      )
      .foregroundStyle(.blue)
    }
    .frame(height: ChartConstants.standardChartHeight)
  }

  // MARK: - Allocation History Section

  private var allocationHistorySection: some View {
    Section {
      CategoryAllocationLineChart(
        entries: viewModel.allocationHistory,
        timeRange: $allocationChartRange
      )
    } header: {
      VStack(alignment: .leading, spacing: 2) {
        Text("Allocation History")
        Text("Based on current category assignments")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Delete Section

  private var deleteSection: some View {
    Section {
      Button("Delete Category", role: .destructive) {
        showDeleteConfirmation = true
      }
      .disabled(!viewModel.canDelete)
      .accessibilityIdentifier("Delete Category Button")

      if let explanation = viewModel.deleteExplanation {
        Text(explanation)
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    } header: {
      Text("Danger Zone")
    }
  }

  // MARK: - Actions

  private func saveChanges() {
    do {
      try viewModel.save()
    } catch {
      saveErrorMessage = error.localizedDescription
      showSaveError = true
    }
  }
}

// MARK: - Previews

#Preview("Category Detail") {
  let container = PreviewContainer.container
  let category = Category(name: "Equities", targetAllocationPercentage: 60)
  container.mainContext.insert(category)
  return NavigationStack {
    CategoryDetailView(category: category, modelContext: container.mainContext) {}
  }
}
