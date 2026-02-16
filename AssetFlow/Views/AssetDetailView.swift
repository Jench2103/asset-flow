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
      }
    }
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
      }
    }
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

  // MARK: - Value History Section

  private var valueHistorySection: some View {
    Section {
      if viewModel.valueHistory.isEmpty {
        Text("No recorded values")
          .foregroundStyle(.secondary)
      } else {
        sparklineChart

        Table(viewModel.valueHistory) {
          TableColumn("Date") { entry in
            Text(entry.date.settingsFormatted())
          }
          TableColumn("Market Value") { entry in
            Text(entry.marketValue.formatted(currency: SettingsService.shared.mainCurrency))
              .monospacedDigit()
          }
          .alignment(.trailing)
        }
        .frame(minHeight: 150)
      }
    } header: {
      Text("Value History")
    }
  }

  private var sparklineChart: some View {
    Chart(viewModel.valueHistory) { entry in
      LineMark(
        x: .value("Date", entry.date),
        y: .value("Value", entry.marketValue.doubleValue)
      )
      .foregroundStyle(.blue)
    }
    .chartXAxis(.hidden)
    .chartYAxis(.hidden)
    .frame(height: 40)
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
