//
//  AssetDetailView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Charts
import SwiftData
import SwiftUI

/// Asset detail view for editing properties and viewing value history.
///
/// Shows editable fields (name, platform, category), a value history table
/// with a sparkline chart, and a delete action with validation.
///
/// **Important:** The parent view must apply `.id(asset.id)` to this view
/// to force view recreation when the selected asset changes, because `@State`
/// ViewModel initialization only runs on first view creation.
struct AssetDetailView: View {
  @State private var viewModel: AssetDetailViewModel

  @State private var showDeleteConfirmation = false
  @State private var showSaveError = false
  @State private var saveErrorMessage = ""
  @State private var valueChartRange: ChartTimeRange = .all
  @State private var hoveredValueDate: Date?
  @State private var editingAssetValue: SnapshotAssetValue?
  @State private var showConvertedChart = false

  @State private var cachedPlatforms: [String] = []
  @State private var cachedCategories: [Category] = []

  let onDelete: () -> Void

  init(asset: Asset, modelContext: ModelContext, onDelete: @escaping () -> Void) {
    _viewModel = State(
      wrappedValue: AssetDetailViewModel(asset: asset, modelContext: modelContext))
    self.onDelete = onDelete
  }

  var body: some View {
    Form {
      editableFieldsSection
      valueHistorySection
      deleteSection
    }
    .formStyle(.grouped)
    .navigationTitle(viewModel.asset.name)
    .onAppear {
      viewModel.loadValueHistory()
      cachedPlatforms = viewModel.existingPlatforms()
      cachedCategories = viewModel.existingCategories()
    }
    .onChange(of: viewModel.isDifferentCurrency) { _, newValue in
      if !newValue { showConvertedChart = false }
    }
    .alert("Save Error", isPresented: $showSaveError) {
      Button("OK") {}
    } message: {
      Text(saveErrorMessage)
    }
    .confirmationDialog(
      "Delete Asset",
      isPresented: $showDeleteConfirmation
    ) {
      Button("Delete", role: .destructive) {
        viewModel.deleteAsset()
        onDelete()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        "Are you sure you want to delete \"\(viewModel.asset.name)\"? This action cannot be undone."
      )
    }
  }

  // MARK: - Editable Fields Section

  private var editableFieldsSection: some View {
    Section {
      TextField("Name", text: $viewModel.editedName)
        .onSubmit { saveChanges() }
        .accessibilityIdentifier("Asset Name Field")

      platformPicker

      categoryPicker

      currencyPicker
    } header: {
      Text("Asset Details")
    }
  }

  // MARK: - Platform Picker

  private var platformPicker: some View {
    PlatformPickerField(
      selectedPlatform: $viewModel.editedPlatform,
      cachedPlatforms: $cachedPlatforms,
      onCommit: { saveChanges() }
    )
    .accessibilityIdentifier("Platform Picker")
  }

  // MARK: - Category Picker

  private var categoryPicker: some View {
    CategoryPickerField(
      selectedCategory: $viewModel.editedCategory,
      cachedCategories: $cachedCategories,
      resolveCategory: { viewModel.resolveCategory(name: $0) },
      onCommit: { saveChanges() }
    )
    .accessibilityIdentifier("Category Picker")
  }

  // MARK: - Currency Picker

  private var currencyPicker: some View {
    Picker("Currency", selection: currencyBinding) {
      ForEach(CurrencyService.shared.currencies) { currency in
        Text(currency.displayName).tag(currency.code)
      }
    }
    .accessibilityIdentifier("Currency Picker")
  }

  private var currencyBinding: Binding<String> {
    Binding(
      get: { viewModel.editedCurrency },
      set: { newValue in
        viewModel.editedCurrency = newValue
        saveChanges()
      }
    )
  }

  // MARK: - Value History Section

  private var filteredValueHistory: [AssetValueHistoryEntry] {
    ChartDataService.filter(viewModel.valueHistory, range: valueChartRange)
  }

  private var valueHistorySection: some View {
    Section {
      if viewModel.valueHistory.isEmpty {
        Text("No recorded values")
          .foregroundStyle(.secondary)
      } else {
        HStack {
          ChartTimeRangeSelector(selection: $valueChartRange)
          Spacer()
          convertedChartToggle
            .opacity(viewModel.isDifferentCurrency ? 1 : 0)
            .allowsHitTesting(viewModel.isDifferentCurrency)
        }

        let points = filteredValueHistory
        if points.isEmpty {
          Text("No data for selected period")
            .foregroundStyle(.secondary)
        } else if showConvertedChart && viewModel.isDifferentCurrency {
          if points.count == 1 {
            singlePointConvertedChart(points)
          } else {
            let displayCurrency = SettingsService.shared.mainCurrency
            assetLineChart(
              points,
              valueFor: { $0.convertedMarketValue ?? $0.marketValue },
              currency: displayCurrency,
              color: .green
            )
          }
        } else if points.count == 1 {
          singlePointValueChart(points)
        } else {
          let effectiveCurrency =
            viewModel.asset.currency.isEmpty
            ? SettingsService.shared.mainCurrency : viewModel.asset.currency
          assetLineChart(
            points,
            valueFor: { $0.marketValue },
            currency: effectiveCurrency,
            color: .blue
          )
        }

        valueHistoryTable
      }
    } header: {
      Text("Value History")
    }
  }

  private func assetLineChart(
    _ points: [AssetValueHistoryEntry],
    valueFor: @escaping (AssetValueHistoryEntry) -> Decimal,
    currency: String,
    color: Color
  ) -> some View {
    let firstDate = points.first!.date
    let lastDate = points.last!.date
    let yValues = points.map { valueFor($0).doubleValue }
    let yMin = yValues.min()!
    let yMax = yValues.max()!
    return Chart(points) { entry in
      let value = valueFor(entry).doubleValue
      LineMark(
        x: .value("Date", entry.date),
        y: .value("Value", value)
      )
      .foregroundStyle(color)
      PointMark(
        x: .value("Date", entry.date),
        y: .value("Value", value)
      )
      .foregroundStyle(color)

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
              Text(valueFor(entry).formatted(currency: currency))
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
          .onContinuousHoverWhenUnlocked { phase in
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

  private func singlePointValueChart(_ points: [AssetValueHistoryEntry]) -> some View {
    Chart(points) { entry in
      PointMark(
        x: .value("Date", entry.date),
        y: .value("Value", entry.marketValue.doubleValue)
      )
      .foregroundStyle(.blue)
    }
    .frame(height: ChartConstants.standardChartHeight)
  }

  // MARK: - Converted Value Chart

  private var convertedChartToggle: some View {
    Button {
      withAnimation(AnimationConstants.chart) { showConvertedChart.toggle() }
    } label: {
      Text(SettingsService.shared.mainCurrency.uppercased())
        .font(.caption2)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
          showConvertedChart
            ? AnyShapeStyle(.tint.opacity(0.15))
            : AnyShapeStyle(.clear)
        )
        .foregroundStyle(showConvertedChart ? .primary : .secondary)
        .clipShape(Capsule())
        .overlay(
          Capsule()
            .stroke(
              showConvertedChart
                ? AnyShapeStyle(.tint.opacity(0.3))
                : AnyShapeStyle(.clear),
              lineWidth: 0.5)
        )
    }
    .buttonStyle(.plain)
    .helpWhenUnlocked("Show values converted to \(SettingsService.shared.mainCurrency)")
    .accessibilityLabel("Show values converted to \(SettingsService.shared.mainCurrency)")
    .accessibilityAddTraits(showConvertedChart ? .isSelected : [])
  }

  private func singlePointConvertedChart(_ points: [AssetValueHistoryEntry]) -> some View {
    Chart(points) { entry in
      PointMark(
        x: .value("Date", entry.date),
        y: .value("Value", (entry.convertedMarketValue ?? entry.marketValue).doubleValue)
      )
      .foregroundStyle(.green)
    }
    .frame(height: ChartConstants.standardChartHeight)
  }

  // MARK: - Value History Table

  private func marketValueCell(
    for entry: AssetValueHistoryEntry, currency: String
  ) -> some View {
    let sav = entry.snapshotAssetValue
    return Text(entry.marketValue.formatted(currency: currency))
      .monospacedDigit()
      .frame(maxWidth: .infinity, alignment: .trailing)
      .contentShape(Rectangle())
      .onTapGesture(count: 2) {
        editingAssetValue = sav
      }
      .contextMenu {
        Button("Edit Value") {
          editingAssetValue = sav
        }
      }
      .popover(
        isPresented: Binding(
          get: { editingAssetValue?.id == sav.id },
          set: { if !$0 { editingAssetValue = nil } }
        ),
        arrowEdge: .trailing
      ) {
        EditValuePopover(currentValue: sav.marketValue) { newValue in
          viewModel.editAssetValue(sav, newValue: newValue)
        }
      }
  }

  private var valueHistoryTable: some View {
    let effectiveCurrency =
      viewModel.asset.currency.isEmpty
      ? SettingsService.shared.mainCurrency : viewModel.asset.currency
    let displayCurrency = SettingsService.shared.mainCurrency
    let showConverted = viewModel.isDifferentCurrency
    let tableHeight = CGFloat(viewModel.valueHistory.count) * 28 + 32

    return Group {
      if showConverted {
        Table(viewModel.valueHistory) {
          TableColumn("Date") { entry in
            Text(entry.date.settingsFormatted())
          }
          TableColumn("Market Value") { entry in
            marketValueCell(for: entry, currency: effectiveCurrency)
          }
          .alignment(.trailing)
          TableColumn("Converted Value") { entry in
            if let converted = entry.convertedMarketValue {
              Text(converted.formatted(currency: displayCurrency))
                .monospacedDigit()
                .frame(maxWidth: .infinity, alignment: .trailing)
            } else {
              Text("—")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
          }
          .alignment(.trailing)
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .scrollDisabled(true)
        .frame(height: tableHeight)
        .padding(-1)
        .clipped()
      } else {
        Table(viewModel.valueHistory) {
          TableColumn("Date") { entry in
            Text(entry.date.settingsFormatted())
          }
          TableColumn("Market Value") { entry in
            marketValueCell(for: entry, currency: effectiveCurrency)
          }
          .alignment(.trailing)
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .scrollDisabled(true)
        .frame(height: tableHeight)
        .padding(-1)
        .clipped()
      }
    }
  }

  // MARK: - Delete Section

  private var deleteSection: some View {
    Section {
      Button("Delete Asset", role: .destructive) {
        showDeleteConfirmation = true
      }
      .disabled(!viewModel.canDelete)
      .accessibilityIdentifier("Delete Asset Button")

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
      cachedPlatforms = viewModel.existingPlatforms()
      cachedCategories = viewModel.existingCategories()
    } catch {
      saveErrorMessage = error.localizedDescription
      showSaveError = true
    }
  }
}

// MARK: - Previews

#Preview("Asset Detail") {
  let container = PreviewContainer.container
  let asset = Asset(name: "AAPL", platform: "Firstrade")
  container.mainContext.insert(asset)
  return NavigationStack {
    AssetDetailView(asset: asset, modelContext: container.mainContext) {}
  }
}
