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
          TableColumn("Value") { row in
            if let value = row.latestValue {
              Text(value.formatted(currency: SettingsService.shared.mainCurrency))
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

  private var valueHistorySection: some View {
    Section {
      if viewModel.valueHistory.isEmpty {
        Text("No value history")
          .foregroundStyle(.secondary)
      } else if viewModel.valueHistory.count == 1 {
        singlePointValueChart
      } else {
        valueLineChart
      }
    } header: {
      Text("Value History")
    }
  }

  private var valueLineChart: some View {
    Chart(viewModel.valueHistory) { entry in
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
    }
    .frame(height: 200)
  }

  private var singlePointValueChart: some View {
    Chart(viewModel.valueHistory) { entry in
      PointMark(
        x: .value("Date", entry.date),
        y: .value("Value", entry.totalValue.doubleValue)
      )
      .foregroundStyle(.blue)
    }
    .frame(height: 200)
  }

  // MARK: - Allocation History Section

  private var allocationHistorySection: some View {
    Section {
      if viewModel.allocationHistory.isEmpty {
        Text("No allocation history")
          .foregroundStyle(.secondary)
      } else if viewModel.allocationHistory.count == 1 {
        singlePointAllocationChart
      } else {
        allocationLineChart
      }
    } header: {
      VStack(alignment: .leading, spacing: 2) {
        Text("Allocation History")
        Text("Based on current category assignments")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
    }
  }

  private var allocationLineChart: some View {
    Chart(viewModel.allocationHistory) { entry in
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
    }
    .chartYScale(domain: 0...100)
    .chartYAxis {
      AxisMarks { value in
        AxisValueLabel {
          if let val = value.as(Double.self) {
            Text(Decimal(Int(val.rounded())).formattedPercentage())
          }
        }
      }
    }
    .frame(height: 200)
  }

  private var singlePointAllocationChart: some View {
    Chart(viewModel.allocationHistory) { entry in
      PointMark(
        x: .value("Date", entry.date),
        y: .value("Allocation", entry.allocationPercentage.doubleValue)
      )
      .foregroundStyle(.green)
    }
    .chartYScale(domain: 0...100)
    .chartYAxis {
      AxisMarks { value in
        AxisValueLabel {
          if let val = value.as(Double.self) {
            Text(Decimal(Int(val.rounded())).formattedPercentage())
          }
        }
      }
    }
    .frame(height: 200)
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
