//
//  CategoryListView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import SwiftData
import SwiftUI

/// Deviation threshold (in percentage points) for showing the warning indicator.
private let significantDeviationThreshold: Decimal = 5

/// Category list view with add sheet and target allocation warning.
///
/// Displays all categories with their target allocation, current allocation,
/// current value, and asset count. Supports adding and deleting categories.
struct CategoryListView: View {
  @State private var viewModel: CategoryListViewModel
  @Binding var selectedCategory: Category?
  @Query private var categories: [Category]
  @Environment(\.isAppLocked) private var isAppLocked

  @State private var showAddSheet = false
  @State private var showDeleteError = false
  @State private var deleteErrorMessage = ""

  init(modelContext: ModelContext, selectedCategory: Binding<Category?>) {
    _viewModel = State(wrappedValue: CategoryListViewModel(modelContext: modelContext))
    _selectedCategory = selectedCategory
  }

  private var categoriesFingerprint: [String] {
    categories.map {
      "\($0.id)-\($0.name)-\(String(describing: $0.targetAllocationPercentage))-\($0.displayOrder)"
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      if let warning = viewModel.targetAllocationSumWarning {
        warningBanner(warning)
          .transition(.move(edge: .top).combined(with: .opacity))
      }

      if viewModel.categoryRows.isEmpty {
        emptyState
      } else {
        categoryList
      }
    }
    .navigationTitle("Categories")
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button {
          showAddSheet = true
        } label: {
          Image(systemName: "plus")
        }
        .disabled(isAppLocked)
        .helpWhenUnlocked("Create a new category")
        .accessibilityIdentifier("Add Category Button")
      }
    }
    .onAppear {
      viewModel.loadCategories()
    }
    .onChange(of: categoriesFingerprint) {
      withAnimation(AnimationConstants.standard) {
        viewModel.loadCategories()
      }
    }
    .sheet(isPresented: $showAddSheet) {
      AddCategorySheet { name, targetAllocation in
        try viewModel.createCategory(name: name, targetAllocation: targetAllocation)
        viewModel.loadCategories()
      }
    }
    .alert("Cannot Delete Category", isPresented: $showDeleteError) {
      Button("OK") {}
    } message: {
      Text(deleteErrorMessage)
    }
  }

  // MARK: - Warning Banner

  private func warningBanner(_ warning: String) -> some View {
    HStack {
      Image(systemName: "exclamationmark.triangle.fill")
        .foregroundStyle(.orange)
      Text(warning)
        .font(.caption)
    }
    .padding(8)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(.yellow.opacity(0.15))
  }

  // MARK: - Category List

  private var categoryList: some View {
    List(selection: $selectedCategory) {
      ForEach(viewModel.categoryRows) { rowData in
        categoryRow(rowData)
          .tag(rowData.category)
      }
      .onMove { source, destination in
        withAnimation(AnimationConstants.list) {
          viewModel.moveCategories(from: source, to: destination)
        }
      }
    }
    .onDeleteCommand {
      deleteSelectedCategory()
    }
    .accessibilityIdentifier("Category List")
  }

  private func deleteSelectedCategory() {
    guard let category = selectedCategory else { return }
    deleteCategory(category)
  }

  private func categoryRow(_ rowData: CategoryRowData) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(rowData.category.name)
          .font(.body)

        if let target = rowData.targetAllocation {
          Text("Target: \(target.formattedPercentage())")
            .font(.caption)
            .foregroundStyle(.secondary)
        } else {
          Text("No target")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }

      Spacer()

      HStack(spacing: 12) {
        if let target = rowData.targetAllocation,
          let current = rowData.currentAllocation
        {
          let deviation = abs(current - target)
          if deviation > significantDeviationThreshold {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundStyle(.orange)
              .font(.caption)
          }
        }

        VStack(alignment: .trailing, spacing: 2) {
          if let current = rowData.currentAllocation {
            Text(current.formattedPercentage())
              .font(.body)
              .monospacedDigit()
          } else {
            Text("\u{2014}")
              .font(.body)
              .foregroundStyle(.secondary)
          }
          Text(rowData.currentValue.formatted(currency: SettingsService.shared.mainCurrency))
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }

        Text("\(rowData.assetCount)")
          .font(.caption)
          .foregroundStyle(.secondary)
          .padding(.horizontal, ChartConstants.badgePaddingH)
          .padding(.vertical, ChartConstants.badgePaddingV)
          .background(.quaternary)
          .clipShape(Capsule())
      }
    }
    .contextMenu {
      if (rowData.category.assets ?? []).isEmpty {
        Button("Delete", role: .destructive) {
          deleteCategory(rowData.category)
        }
      }
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    ContentUnavailableView {
      Label("No Categories", systemImage: "folder")
    } description: {
      Text(
        "No categories yet. Create categories to organize your assets and set target allocations."
      )
    } actions: {
      Button("Create Category") {
        showAddSheet = true
      }
      .buttonStyle(.borderedProminent)
    }
  }

  // MARK: - Actions

  private func deleteCategory(_ category: Category) {
    do {
      try viewModel.deleteCategory(category)
      if selectedCategory?.id == category.id {
        selectedCategory = nil
      }
      withAnimation(AnimationConstants.standard) {
        viewModel.loadCategories()
      }
    } catch {
      deleteErrorMessage = error.localizedDescription
      showDeleteError = true
    }
  }
}

// MARK: - Add Category Sheet

private struct AddCategorySheet: View {
  let onCreate: (String, Decimal?) throws -> Void

  @Environment(\.dismiss) private var dismiss
  @FocusState private var focusedField: Field?
  enum Field { case name, targetAllocation }

  @State private var name = ""
  @State private var targetAllocationText = ""
  @State private var showError = false
  @State private var errorMessage = ""

  var body: some View {
    NavigationStack {
      Form {
        TextField("Category Name", text: $name)
          .focused($focusedField, equals: .name)
          .accessibilityIdentifier("Category Name Field")

        TextField("Target Allocation (e.g. 40)", text: $targetAllocationText)
          .focused($focusedField, equals: .targetAllocation)
          .accessibilityIdentifier("Target Allocation Field")

        Text("Optional. Enter a value between 0 and 100.")
          .font(.caption)
          .foregroundStyle(.secondary)
      }
      .formStyle(.grouped)
      .navigationTitle("New Category")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") {
            createCategory()
          }
          .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
      }
    }
    .frame(minWidth: 350, minHeight: 220)
    .onAppear { focusedField = .name }
    .alert("Error", isPresented: $showError) {
      Button("OK") {}
    } message: {
      Text(errorMessage)
    }
  }

  private func createCategory() {
    let targetAllocation: Decimal?
    if targetAllocationText.trimmingCharacters(in: .whitespaces).isEmpty {
      targetAllocation = nil
    } else if let value = Decimal(string: targetAllocationText) {
      targetAllocation = value
    } else {
      errorMessage = String(
        localized: "Invalid target allocation value.",
        table: "Category")
      showError = true
      return
    }

    do {
      try onCreate(name, targetAllocation)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
      showError = true
    }
  }
}

// MARK: - Previews

#Preview("Category List") {
  NavigationStack {
    CategoryListView(
      modelContext: PreviewContainer.container.mainContext,
      selectedCategory: .constant(nil)
    )
  }
}
