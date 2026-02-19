//
//  SnapshotDetailView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import SwiftData
import SwiftUI

/// Snapshot detail view with full CRUD for asset values and cash flow operations.
///
/// Shows a summary section, asset breakdown,
/// category allocation, cash flow operations, and a danger zone for snapshot deletion.
///
/// **Important:** The parent view must apply `.id(snapshot.id)` to this view
/// to force view recreation when the selected snapshot changes.
struct SnapshotDetailView: View {
  @State private var viewModel: SnapshotDetailViewModel

  @State private var showAddAssetSheet = false
  @State private var showAddCashFlowSheet = false
  @State private var showDeleteConfirmation = false

  @State private var editingAssetValue: SnapshotAssetValue?
  @State private var editingCashFlow: CashFlowOperation?

  @State private var showError = false
  @State private var errorMessage = ""

  let onDelete: () -> Void

  init(snapshot: Snapshot, modelContext: ModelContext, onDelete: @escaping () -> Void) {
    _viewModel = State(
      wrappedValue: SnapshotDetailViewModel(snapshot: snapshot, modelContext: modelContext))
    self.onDelete = onDelete
  }

  var body: some View {
    Form {
      summarySection
      assetBreakdownSection
      categoryAllocationSection
      cashFlowSection
      dangerZoneSection
    }
    .formStyle(.grouped)
    .navigationTitle(
      viewModel.snapshot.date.settingsFormatted()
    )
    .onAppear {
      viewModel.loadAssetValues()
    }
    .alert("Error", isPresented: $showError) {
      Button("OK") {}
    } message: {
      Text(errorMessage)
    }
    .sheet(isPresented: $showAddAssetSheet) {
      AddAssetSheet(viewModel: viewModel) {
        viewModel.loadAssetValues()
      }
    }
    .sheet(isPresented: $showAddCashFlowSheet) {
      AddCashFlowSheet(viewModel: viewModel) {
        viewModel.loadAssetValues()
      }
    }
    .confirmationDialog(
      "Delete Snapshot",
      isPresented: $showDeleteConfirmation
    ) {
      Button("Delete", role: .destructive) {
        viewModel.deleteSnapshot()
        onDelete()
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      let data = viewModel.deleteConfirmationData()
      let dateStr = data.date.settingsFormatted()
      let assetCount = data.assetCount
      let cfCount = data.cashFlowCount
      Text(
        "Delete snapshot from \(dateStr)? This will remove all \(assetCount) asset values and \(cfCount) cash flow operations. This action cannot be undone."
      )
    }
  }

  // MARK: - Summary Section

  private var summarySection: some View {
    Section {
      LabeledContent("Total Value") {
        Text(viewModel.totalValue.formatted(currency: SettingsService.shared.mainCurrency))
          .monospacedDigit()
      }

      let operations = viewModel.snapshot.cashFlowOperations ?? []
      LabeledContent("Net Cash Flow") {
        HStack(spacing: 4) {
          Text(viewModel.netCashFlow.formatted(currency: SettingsService.shared.mainCurrency))
            .monospacedDigit()
          Text("(\(operations.count) operations)")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
    } header: {
      Text("Summary")
    }
  }

  // MARK: - Asset Breakdown Section

  private var assetBreakdownSection: some View {
    Section {
      if viewModel.sortedAssetValues.isEmpty {
        Text("No assets in this snapshot")
          .foregroundStyle(.secondary)
      } else {
        ForEach(viewModel.sortedAssetValues, id: \.id) { sav in
          if let asset = sav.asset {
            assetRow(sav, asset: asset)
          }
        }
      }
    } header: {
      HStack {
        Text("Assets")
        Spacer()
        Button {
          showAddAssetSheet = true
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.plain)
      }
    }
  }

  @ViewBuilder
  private func assetRow(_ sav: SnapshotAssetValue, asset: Asset) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(asset.name)
          .font(.body)
        HStack(spacing: 8) {
          if !asset.platform.isEmpty { Text(asset.platform) }
          if let categoryName = asset.category?.name { Text(categoryName) }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }
      Spacer()
      Text(sav.marketValue.formatted(currency: SettingsService.shared.mainCurrency))
        .font(.body)
        .monospacedDigit()
    }
    .contentShape(Rectangle())
    .contextMenu {
      Button("Edit Value") {
        editingAssetValue = sav
      }
      Button("Remove from Snapshot", role: .destructive) {
        viewModel.removeAsset(sav)
        viewModel.loadAssetValues()
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
        do {
          try viewModel.editAssetValue(sav, newValue: newValue)
          viewModel.loadAssetValues()
        } catch {
          errorMessage = error.localizedDescription
          showError = true
        }
      }
    }
  }

  // MARK: - Category Allocation Section

  private var categoryAllocationSection: some View {
    Section {
      if viewModel.categoryAllocations.isEmpty {
        Text("No category data")
          .foregroundStyle(.secondary)
      } else {
        ForEach(viewModel.categoryAllocations, id: \.categoryName) { allocation in
          HStack {
            Text(allocation.categoryName)
              .font(.body)
            Spacer()
            Text(allocation.value.formatted(currency: SettingsService.shared.mainCurrency))
              .font(.body)
              .monospacedDigit()
            Text(allocation.percentage.formattedPercentage())
              .font(.caption)
              .foregroundStyle(.secondary)
              .frame(width: 60, alignment: .trailing)
          }
        }
      }
    } header: {
      Text("Category Allocation")
    }
  }

  // MARK: - Cash Flow Section

  private var cashFlowSection: some View {
    Section {
      let operations = viewModel.sortedCashFlowOperations
      if operations.isEmpty {
        Text("No cash flow operations")
          .foregroundStyle(.secondary)
      } else {
        ForEach(operations) { operation in
          let direction = operation.amount < 0 ? "outflow" : "inflow"
          let formatted = operation.amount.formatted(currency: SettingsService.shared.mainCurrency)
          HStack {
            Text(operation.cashFlowDescription)
              .font(.body)
            Spacer()
            Text(formatted)
              .font(.body)
              .monospacedDigit()
              .foregroundStyle(operation.amount < 0 ? .red : .primary)
          }
          .accessibilityLabel("\(operation.cashFlowDescription), \(direction), \(formatted)")
          .contextMenu {
            Button("Edit") {
              editingCashFlow = operation
            }
            Button("Remove", role: .destructive) {
              viewModel.removeCashFlow(operation)
            }
          }
          .popover(
            isPresented: Binding(
              get: { editingCashFlow?.id == operation.id },
              set: { if !$0 { editingCashFlow = nil } }
            ),
            arrowEdge: .trailing
          ) {
            EditCashFlowPopover(
              currentDescription: operation.cashFlowDescription,
              currentAmount: operation.amount
            ) { newDescription, newAmount in
              do {
                try viewModel.editCashFlow(
                  operation, newDescription: newDescription, newAmount: newAmount)
              } catch {
                errorMessage = error.localizedDescription
                showError = true
              }
            }
          }
        }

        LabeledContent("Net Cash Flow") {
          Text(viewModel.netCashFlow.formatted(currency: SettingsService.shared.mainCurrency))
            .monospacedDigit()
            .fontWeight(.semibold)
        }
      }
    } header: {
      HStack {
        Text("Cash Flow Operations")
        Spacer()
        Button {
          showAddCashFlowSheet = true
        } label: {
          Image(systemName: "plus")
        }
        .buttonStyle(.plain)
      }
    }
  }

  // MARK: - Danger Zone Section

  private var dangerZoneSection: some View {
    Section {
      Button("Delete Snapshot", role: .destructive) {
        showDeleteConfirmation = true
      }
      .accessibilityIdentifier("Delete Snapshot Button")
    } header: {
      Text("Danger Zone")
    }
  }

}

// MARK: - Add Asset Sheet

private struct AddAssetSheet: View {
  let viewModel: SnapshotDetailViewModel
  let onComplete: () -> Void

  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  @State private var mode: AddAssetMode = .selectExisting
  @State private var showError = false
  @State private var errorMessage = ""

  // Select Existing mode
  @State private var selectedAsset: Asset?
  @State private var marketValueText = ""

  // Create New mode
  @State private var newAssetName = ""
  @State private var newPlatform = ""
  @State private var showNewPlatformField = false
  @State private var newPlatformName = ""
  @State private var newCategory: Category?
  @State private var showNewCategoryField = false
  @State private var newCategoryName = ""
  @State private var newMarketValueText = ""

  @Query(sort: \Asset.name) private var allAssets: [Asset]

  @State private var cachedPlatforms: [String] = []
  @State private var cachedCategories: [Category] = []

  enum AddAssetMode: String, CaseIterable {
    case selectExisting = "Select Existing"
    case createNew = "Create New"

    var localizedName: String {
      switch self {
      case .selectExisting:
        return String(localized: "Select Existing", table: "Snapshot")

      case .createNew:
        return String(localized: "Create New", table: "Snapshot")
      }
    }
  }

  var body: some View {
    VStack(spacing: 0) {
      Text("Add Asset")
        .font(.headline)
        .padding(.top, 16)
        .padding(.horizontal)

      Picker("Mode", selection: $mode) {
        ForEach(AddAssetMode.allCases, id: \.self) { mode in
          Text(mode.localizedName).tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .padding(.horizontal)

      Form {
        switch mode {
        case .selectExisting:
          selectExistingForm

        case .createNew:
          createNewForm
        }
      }
      .formStyle(.grouped)

      HStack {
        Button("Cancel", role: .cancel) {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Spacer()

        Button("Add") {
          addAsset()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(isAddDisabled)
      }
      .padding()
    }
    .frame(minWidth: 400, minHeight: 300)
    .onAppear {
      cachedPlatforms = existingPlatforms()
      cachedCategories = existingCategories()
    }
    .alert("Error", isPresented: $showError) {
      Button("OK") {}
    } message: {
      Text(errorMessage)
    }
  }

  private var selectExistingForm: some View {
    Group {
      Picker("Asset", selection: $selectedAsset) {
        Text("Select an asset").tag(nil as Asset?)
        ForEach(allAssets) { asset in
          Text(assetDisplayName(asset)).tag(asset as Asset?)
        }
      }

      if let asset = selectedAsset {
        LabeledContent("Platform") {
          Text(asset.platform.isEmpty ? "\u{2014}" : asset.platform)
            .foregroundStyle(asset.platform.isEmpty ? .secondary : .primary)
        }
        LabeledContent("Category") {
          Text(asset.category?.name ?? "\u{2014}")
            .foregroundStyle(asset.category == nil ? .secondary : .primary)
        }
      }

      TextField("Market Value", text: $marketValueText)
        .accessibilityIdentifier("Market Value Field")
    }
  }

  @ViewBuilder
  private var createNewForm: some View {
    TextField("Asset Name", text: $newAssetName)

    platformPicker

    categoryPicker

    TextField("Market Value", text: $newMarketValueText)
      .accessibilityIdentifier("New Market Value Field")
  }

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
      }
    }
  }

  private var platformBinding: Binding<String> {
    Binding(
      get: { newPlatform },
      set: { value in
        if value == "__new__" {
          showNewPlatformField = true
          newPlatformName = ""
        } else {
          newPlatform = value
        }
      }
    )
  }

  private func commitNewPlatform() {
    let trimmed = newPlatformName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    let platforms = existingPlatforms()
    if let match = platforms.first(where: { $0.lowercased() == trimmed.lowercased() }) {
      newPlatform = match
    } else {
      newPlatform = trimmed
    }
    showNewPlatformField = false
    newPlatformName = ""
    // Refresh cache so picker shows new platform
    var updated = existingPlatforms()
    if !updated.contains(newPlatform) {
      updated.append(newPlatform)
      updated.sort()
    }
    cachedPlatforms = updated
  }

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
      }
    }
  }

  private var categoryBinding: Binding<String> {
    Binding(
      get: { newCategory?.id.uuidString ?? "" },
      set: { value in
        if value == "__new__" {
          showNewCategoryField = true
          newCategoryName = ""
        } else if value.isEmpty {
          newCategory = nil
        } else {
          newCategory = cachedCategories.first { $0.id.uuidString == value }
        }
      }
    )
  }

  private func commitNewCategory() {
    let trimmed = newCategoryName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    newCategory = viewModel.resolveCategory(name: trimmed)
    showNewCategoryField = false
    newCategoryName = ""
    // Refresh cache so picker shows new category
    cachedCategories = existingCategories()
  }

  private var isAddDisabled: Bool {
    switch mode {
    case .selectExisting:
      return selectedAsset == nil || Decimal(string: marketValueText) == nil

    case .createNew:
      return newAssetName.trimmingCharacters(in: .whitespaces).isEmpty
        || Decimal(string: newMarketValueText) == nil
    }
  }

  private func addAsset() {
    do {
      switch mode {
      case .selectExisting:
        guard let asset = selectedAsset,
          let value = Decimal(string: marketValueText)
        else { return }
        try viewModel.addExistingAsset(asset, marketValue: value)

      case .createNew:
        guard let value = Decimal(string: newMarketValueText) else { return }
        try viewModel.addNewAsset(
          name: newAssetName,
          platform: newPlatform,
          category: newCategory,
          marketValue: value
        )
      }
      onComplete()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
      showError = true
    }
  }

  private func assetDisplayName(_ asset: Asset) -> String {
    if asset.platform.isEmpty {
      return asset.name
    }
    return "\(asset.name) (\(asset.platform))"
  }

  private func existingPlatforms() -> [String] {
    let platforms = Set(allAssets.map(\.platform).filter { !$0.isEmpty })
    return platforms.sorted()
  }

  private func existingCategories() -> [Category] {
    let descriptor = FetchDescriptor<Category>(sortBy: [SortDescriptor(\.name)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }
}

// MARK: - Add Cash Flow Sheet

private struct AddCashFlowSheet: View {
  let viewModel: SnapshotDetailViewModel
  let onComplete: () -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var description = ""
  @State private var amountText = ""
  @State private var showError = false
  @State private var errorMessage = ""

  var body: some View {
    VStack(spacing: 0) {
      Text("Add Cash Flow")
        .font(.headline)
        .padding(.top, 16)
        .padding(.horizontal)

      Form {
        TextField("Description", text: $description)
          .accessibilityIdentifier("Cash Flow Description Field")

        TextField("Amount (positive = inflow, negative = outflow)", text: $amountText)
          .accessibilityIdentifier("Cash Flow Amount Field")
      }
      .formStyle(.grouped)

      HStack {
        Button("Cancel", role: .cancel) {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Spacer()

        Button("Add") {
          addCashFlow()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(
          description.trimmingCharacters(in: .whitespaces).isEmpty
            || Decimal(string: amountText) == nil
        )
      }
      .padding()
    }
    .frame(minWidth: 350, minHeight: 180)
    .alert("Error", isPresented: $showError) {
      Button("OK") {}
    } message: {
      Text(errorMessage)
    }
  }

  private func addCashFlow() {
    guard let amount = Decimal(string: amountText) else { return }
    do {
      try viewModel.addCashFlow(description: description, amount: amount)
      onComplete()
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
      showError = true
    }
  }
}

// MARK: - Edit Value Popover

private struct EditValuePopover: View {
  let currentValue: Decimal
  let onSave: (Decimal) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var valueText: String

  init(currentValue: Decimal, onSave: @escaping (Decimal) -> Void) {
    self.currentValue = currentValue
    self.onSave = onSave
    _valueText = State(wrappedValue: NSDecimalNumber(decimal: currentValue).stringValue)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Market Value").font(.headline)
      TextField("Market Value", text: $valueText)
        .textFieldStyle(.roundedBorder)
        .accessibilityIdentifier("Edit Market Value Field")
      HStack {
        Button("Cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button("Save") {
          if let newValue = Decimal(string: valueText) {
            onSave(newValue)
            dismiss()
          }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(Decimal(string: valueText) == nil)
      }
    }
    .frame(width: 280)
    .padding()
  }
}

// MARK: - Edit Cash Flow Popover

private struct EditCashFlowPopover: View {
  let currentDescription: String
  let currentAmount: Decimal
  let onSave: (String, Decimal) -> Void
  @Environment(\.dismiss) private var dismiss
  @State private var description: String
  @State private var amountText: String

  init(
    currentDescription: String,
    currentAmount: Decimal,
    onSave: @escaping (String, Decimal) -> Void
  ) {
    self.currentDescription = currentDescription
    self.currentAmount = currentAmount
    self.onSave = onSave
    _description = State(wrappedValue: currentDescription)
    _amountText = State(wrappedValue: NSDecimalNumber(decimal: currentAmount).stringValue)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Edit Cash Flow").font(.headline)
      TextField("Description", text: $description)
        .textFieldStyle(.roundedBorder)
      TextField("Amount", text: $amountText)
        .textFieldStyle(.roundedBorder)
      HStack {
        Button("Cancel", role: .cancel) { dismiss() }
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button("Save") {
          if let amount = Decimal(string: amountText) {
            onSave(description, amount)
            dismiss()
          }
        }
        .keyboardShortcut(.defaultAction)
        .disabled(
          description.trimmingCharacters(in: .whitespaces).isEmpty
            || Decimal(string: amountText) == nil
        )
      }
    }
    .frame(width: 280)
    .padding()
  }
}

// MARK: - Previews

#Preview("Snapshot Detail") {
  let container = PreviewContainer.container
  let snapshot = Snapshot(date: Date())
  container.mainContext.insert(snapshot)
  return NavigationStack {
    SnapshotDetailView(snapshot: snapshot, modelContext: container.mainContext) {}
  }
}
