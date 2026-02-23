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

  @State private var newPlatformName = ""
  @State private var showNewPlatformField = false

  @State private var newCategoryName = ""
  @State private var showNewCategoryField = false

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
    VStack(alignment: .leading, spacing: 4) {
      if showNewPlatformField {
        HStack {
          TextField("New platform name", text: $newPlatformName)
            .textFieldStyle(.roundedBorder)
            .onSubmit { commitNewPlatform() }
          Button("OK") { commitNewPlatform() }
          Button("Cancel") {
            showNewPlatformField = false
            newPlatformName = ""
          }
        }
        .transition(.opacity)
      } else {
        Picker("Platform", selection: platformBinding) {
          Text("None").tag("")
          ForEach(cachedPlatforms, id: \.self) { platform in
            Text(platform).tag(platform)
          }
          Divider()
          Text("New Platform...").tag("__new__")
        }
        .accessibilityIdentifier("Platform Picker")
        .transition(.opacity)
      }
    }
    .animation(AnimationConstants.standard, value: showNewPlatformField)
  }

  private var platformBinding: Binding<String> {
    Binding(
      get: { viewModel.editedPlatform },
      set: { newValue in
        if newValue == "__new__" {
          showNewPlatformField = true
          newPlatformName = ""
        } else {
          viewModel.editedPlatform = newValue
          saveChanges()
        }
      }
    )
  }

  private func commitNewPlatform() {
    let trimmed = newPlatformName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }

    let platforms = cachedPlatforms
    if let match = platforms.first(where: { $0.lowercased() == trimmed.lowercased() }) {
      viewModel.editedPlatform = match
    } else {
      viewModel.editedPlatform = trimmed
    }

    showNewPlatformField = false
    newPlatformName = ""
    saveChanges()
  }

  // MARK: - Category Picker

  private var categoryPicker: some View {
    VStack(alignment: .leading, spacing: 4) {
      if showNewCategoryField {
        HStack {
          TextField("New category name", text: $newCategoryName)
            .textFieldStyle(.roundedBorder)
            .onSubmit { commitNewCategory() }
          Button("OK") { commitNewCategory() }
          Button("Cancel") {
            showNewCategoryField = false
            newCategoryName = ""
          }
        }
        .transition(.opacity)
      } else {
        Picker("Category", selection: categoryBinding) {
          Text("None").tag("")
          ForEach(cachedCategories) { category in
            Text(category.name).tag(category.id.uuidString)
          }
          Divider()
          Text("New Category...").tag("__new__")
        }
        .accessibilityIdentifier("Category Picker")
        .transition(.opacity)
      }
    }
    .animation(AnimationConstants.standard, value: showNewCategoryField)
  }

  private var categoryBinding: Binding<String> {
    Binding(
      get: { viewModel.editedCategory?.id.uuidString ?? "" },
      set: { newValue in
        if newValue == "__new__" {
          showNewCategoryField = true
          newCategoryName = ""
        } else if newValue.isEmpty {
          viewModel.editedCategory = nil
          saveChanges()
        } else {
          let categories = cachedCategories
          viewModel.editedCategory = categories.first { $0.id.uuidString == newValue }
          saveChanges()
        }
      }
    )
  }

  private func commitNewCategory() {
    let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }

    let resolved = viewModel.resolveCategory(name: trimmed)
    viewModel.editedCategory = resolved

    showNewCategoryField = false
    newCategoryName = ""
    saveChanges()
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
        ChartTimeRangeSelector(selection: $valueChartRange)

        let points = filteredValueHistory
        if points.isEmpty {
          Text("No data for selected period")
            .foregroundStyle(.secondary)
        } else if points.count == 1 {
          singlePointValueChart(points)
        } else {
          valueLineChart(points)
        }

        Table(viewModel.valueHistory) {
          TableColumn("Date") { entry in
            Text(entry.date.settingsFormatted())
          }
          TableColumn("Market Value") { entry in
            let effectiveCurrency =
              viewModel.asset.currency.isEmpty
              ? SettingsService.shared.mainCurrency : viewModel.asset.currency
            let sav = entry.snapshotAssetValue
            Text(entry.marketValue.formatted(currency: effectiveCurrency))
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
          .alignment(.trailing)
        }
        .tableStyle(.bordered(alternatesRowBackgrounds: true))
        .scrollDisabled(true)
        .frame(height: CGFloat(viewModel.valueHistory.count) * 28 + 32)
        .padding(-1)
        .clipped()
      }
    } header: {
      Text("Value History")
    }
  }

  private func valueLineChart(_ points: [AssetValueHistoryEntry]) -> some View {
    let firstDate = points.first!.date
    let lastDate = points.last!.date
    let yValues = points.map { $0.marketValue.doubleValue }
    let yMin = yValues.min()!
    let yMax = yValues.max()!
    return Chart(points) { entry in
      LineMark(
        x: .value("Date", entry.date),
        y: .value("Value", entry.marketValue.doubleValue)
      )
      .foregroundStyle(.blue)
      PointMark(
        x: .value("Date", entry.date),
        y: .value("Value", entry.marketValue.doubleValue)
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
              let effectiveCurrency =
                viewModel.asset.currency.isEmpty
                ? SettingsService.shared.mainCurrency : viewModel.asset.currency
              Text(entry.date.settingsFormatted())
                .font(.caption2)
              Text(entry.marketValue.formatted(currency: effectiveCurrency))
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
