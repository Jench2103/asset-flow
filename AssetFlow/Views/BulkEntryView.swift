//  AssetFlow — snapshot-based portfolio management for macOS.
//  Copyright (C) 2026 Jen-Chien Chang
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Full-screen view for bulk snapshot entry with a platform-grouped table.
///
/// Displays all assets from the most recent snapshot, grouped by platform,
/// allowing the user to enter new values for each asset. Supports per-platform
/// CSV import, inline asset creation, and keyboard navigation between rows.
struct BulkEntryView: View {
  @State var viewModel: BulkEntryViewModel
  let onSave: (Snapshot) -> Void

  @Environment(\.modelContext) private var modelContext
  @FocusState private var focusedRowID: UUID?
  @State private var showZeroPendingConfirmation = false
  @State private var csvImportPlatform: String = ""
  @State private var showCSVImporter = false
  @State private var showError = false
  @State private var errorMessage = ""
  @State private var showImportResult = false
  @State private var importResultTitle = ""
  @State private var importResultMessage = ""
  @State private var showAddPlatformPopover = false
  @State private var newPlatformName = ""
  @State private var addPlatformError = ""
  @State private var cachedCategoryNames: [String] = []

  var body: some View {
    VStack(spacing: 0) {
      toolbar
      Divider()
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
          ForEach(viewModel.platformGroups, id: \.platform) { group in
            platformSection(group)
          }
          if viewModel.rows.isEmpty {
            ContentUnavailableView {
              Label("No Assets", systemImage: "tray")
            } description: {
              Text(
                "Add a platform to start building your snapshot, or import assets from a CSV file."
              )
            } actions: {
              Button("Add Platform") {
                newPlatformName = ""
                addPlatformError = ""
                showAddPlatformPopover = true
              }
              .buttonStyle(.borderedProminent)
            }
          }
        }
        .padding()
      }
    }
    .onAppear {
      loadCachedCategoryNames()
    }
    .fileImporter(
      isPresented: $showCSVImporter,
      allowedContentTypes: [.commaSeparatedText, .plainText]
    ) { result in
      let platform = csvImportPlatform
      guard !platform.isEmpty,
        let url = try? result.get()
      else { return }
      if url.startAccessingSecurityScopedResource() {
        defer { url.stopAccessingSecurityScopedResource() }
        if let data = try? Data(contentsOf: url) {
          let importResult = viewModel.importCSV(data: data, forPlatform: platform)
          let formatted = formatImportResult(importResult)
          importResultTitle = formatted.title
          importResultMessage = formatted.message
          showImportResult = true
        }
      }
    }
    .alert(
      String(
        localized:
          "\(viewModel.pendingCount) assets will be saved with a value of 0. Continue?",
        table: "Snapshot"),
      isPresented: $showZeroPendingConfirmation
    ) {
      Button("Continue") { performSave() }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text(
        String(
          localized:
            "You can update these values later in the snapshot detail view.",
          table: "Snapshot"))
    }
    .alert("Error", isPresented: $showError) {
      Button("OK") {}
    } message: {
      Text(errorMessage)
    }
    .alert(importResultTitle, isPresented: $showImportResult) {
      Button("OK") {}
    } message: {
      Text(importResultMessage)
    }
  }

  // MARK: - Toolbar

  private var toolbar: some View {
    HStack(spacing: 16) {
      Text("New Snapshot — \(viewModel.snapshotDate.settingsFormatted())")
        .font(.headline)

      Spacer()

      progressStats

      if viewModel.zeroValueCount > 0 {
        Label(
          String(
            localized:
              "\(viewModel.zeroValueCount) assets have a value of 0. Exclude them or enter a non-zero value.",
            table: "Snapshot"),
          systemImage: "exclamationmark.triangle.fill"
        )
        .font(.callout)
        .foregroundStyle(.red)
      }

      if viewModel.hasInvalidNewRows {
        Label(
          String(
            localized: "Some new assets are missing a name.",
            table: "Snapshot"),
          systemImage: "exclamationmark.triangle.fill"
        )
        .font(.callout)
        .foregroundStyle(.red)
      }

      if viewModel.hasDuplicateNames {
        Label(
          String(
            localized: "Duplicate asset names found within a platform.",
            table: "Snapshot"),
          systemImage: "exclamationmark.triangle.fill"
        )
        .font(.callout)
        .foregroundStyle(.red)
      }

      Button {
        newPlatformName = ""
        addPlatformError = ""
        showAddPlatformPopover = true
      } label: {
        Label("Add Platform", systemImage: "plus.rectangle.on.folder")
      }
      .helpWhenUnlocked("Add a new platform with an empty asset")
      .popover(isPresented: $showAddPlatformPopover) {
        addPlatformPopover
      }

      Button("Save Snapshot") {
        handleSave()
      }
      .buttonStyle(.borderedProminent)
      .disabled(!viewModel.canSave)
      .helpWhenUnlocked("Save the snapshot with entered values")
      .accessibilityIdentifier("Save Snapshot Button")
    }
    .padding(.horizontal)
    .padding(.vertical, 12)
  }

  private var progressStats: some View {
    HStack(spacing: 12) {
      HStack(spacing: 4) {
        Circle()
          .fill(.green)
          .frame(width: 8, height: 8)
        Text("\(viewModel.updatedCount) updated")
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 4) {
        Circle()
          .fill(.orange)
          .frame(width: 8, height: 8)
        Text("\(viewModel.pendingCount) pending")
          .font(.callout)
          .foregroundStyle(.secondary)
      }

      HStack(spacing: 4) {
        Circle()
          .fill(.gray)
          .frame(width: 8, height: 8)
        Text("\(viewModel.excludedCount) excluded")
          .font(.callout)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Add Platform Popover

  private var addPlatformPopover: some View {
    VStack(spacing: 12) {
      Text("New Platform")
        .font(.headline)
      TextField("Platform name", text: $newPlatformName)
        .textFieldStyle(.roundedBorder)
        .onSubmit { commitNewPlatform() }
      if !addPlatformError.isEmpty {
        Text(addPlatformError)
          .font(.caption)
          .foregroundStyle(.red)
      }
      HStack {
        Button("Cancel") { showAddPlatformPopover = false }
        Button("Add") { commitNewPlatform() }
          .buttonStyle(.borderedProminent)
          .disabled(newPlatformName.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .padding()
    .frame(width: 260)
  }

  private func commitNewPlatform() {
    let trimmed = newPlatformName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
      addPlatformError = String(
        localized: "Platform name cannot be empty.", table: "Snapshot")
      return
    }
    if let rowID = viewModel.addPlatform(name: trimmed) {
      showAddPlatformPopover = false
      Task { @MainActor in
        focusedRowID = rowID
      }
    } else {
      addPlatformError = String(
        localized: "A platform with this name already exists.", table: "Snapshot")
    }
  }

  // MARK: - Platform Section

  @ViewBuilder
  private func platformSection(
    _ group: (platform: String, rows: [BulkEntryRow])
  ) -> some View {
    let duplicateIDs = viewModel.duplicateNameRowIDs
    VStack(alignment: .leading, spacing: 0) {
      platformHeader(group)
      columnHeaders
      ForEach(group.rows) { row in
        assetEntryRow(row, duplicateIDs: duplicateIDs)
        Divider()
      }
    }
    .padding(.bottom, 16)
  }

  private func platformHeader(
    _ group: (platform: String, rows: [BulkEntryRow])
  ) -> some View {
    HStack(spacing: 12) {
      Text(group.platform.isEmpty ? "No Platform" : group.platform)
        .font(.title3)
        .fontWeight(.bold)

      Text("\(group.rows.count)")
        .font(.caption)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(.quaternary, in: Capsule())

      let groupUpdated = group.rows.filter(\.isUpdated).count
      let groupTotal = group.rows.filter(\.isIncluded).count
      Text("\(groupUpdated)/\(groupTotal)")
        .font(.caption)
        .foregroundStyle(.secondary)

      Spacer()

      Button {
        let rowID = viewModel.addManualRow(forPlatform: group.platform)
        Task { @MainActor in
          focusedRowID = rowID
        }
      } label: {
        Label("Add Asset", systemImage: "plus")
          .font(.callout)
      }
      .helpWhenUnlocked("Add a new asset to this platform")

      Button {
        csvImportPlatform = group.platform
        showCSVImporter = true
      } label: {
        Label("Import CSV", systemImage: "doc.text")
          .font(.callout)
      }
      .helpWhenUnlocked("Import a CSV file to fill values for this platform")
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 4)
  }

  private var columnHeaders: some View {
    HStack(spacing: 8) {
      Text("Include")
        .frame(width: 60, alignment: .center)
      Text("Asset Name")
        .frame(minWidth: 120, alignment: .leading)
      Spacer()
      Text("Category")
        .frame(width: 120, alignment: .center)
      Text("Currency")
        .frame(width: 80, alignment: .center)
      Text("Previous Value")
        .frame(width: 140, alignment: .trailing)
      Text("New Value")
        .frame(width: 160, alignment: .trailing)
      Spacer()
        .frame(width: 28)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.vertical, 4)
    .padding(.horizontal, 4)
    .background(.fill.quaternary)
  }

  // MARK: - Asset Entry Row

  @ViewBuilder
  private func assetEntryRow(_ row: BulkEntryRow, duplicateIDs: Set<UUID>) -> some View {
    let isExcluded = !row.isIncluded
    let isUpdated = row.isUpdated
    let isDuplicate = duplicateIDs.contains(row.id)

    HStack(spacing: 8) {
      Toggle("", isOn: includeBinding(for: row))
        .labelsHidden()
        .accessibilityLabel("Include \(row.assetName)")
        .frame(width: 60, alignment: .center)
        .helpWhenUnlocked("Include or exclude this asset from the snapshot")

      // Asset name column
      HStack(spacing: 6) {
        if row.isNewRow {
          TextField("Asset name", text: assetNameBinding(for: row))
            .textFieldStyle(.roundedBorder)
            .frame(minWidth: 100)
            .disabled(isExcluded)
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(
                  (row.hasEmptyName || isDuplicate) ? .red : .clear,
                  lineWidth: 1.5)
            )
        } else {
          Text(row.assetName)
            .strikethrough(isExcluded)
        }
        sourceBadge(for: row)
      }
      .frame(minWidth: 120, alignment: .leading)

      Spacer()

      // Category column
      if row.isNewAsset {
        categoryPicker(for: row)
          .frame(width: 120)
      } else {
        Text(row.asset?.category?.name ?? "\u{2014}")
          .font(.callout)
          .foregroundStyle(row.asset?.category != nil ? .primary : .secondary)
          .frame(width: 120, alignment: .center)
      }

      // Currency column
      if row.isNewRow {
        Picker("", selection: currencyBinding(for: row)) {
          ForEach(CurrencyService.shared.currencies) { currency in
            Text(currency.code).tag(currency.code)
          }
        }
        .labelsHidden()
        .frame(width: 80)
      } else {
        Text(row.currency.uppercased())
          .font(.callout)
          .frame(width: 80, alignment: .center)
      }

      Text(row.previousValue?.formatted(currency: row.currency) ?? "\u{2014}")
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .frame(width: 140, alignment: .trailing)

      TextField("Enter value\u{2026}", text: bindingForRow(row))
        .textFieldStyle(.roundedBorder)
        .monospacedDigit()
        .frame(width: 160)
        .multilineTextAlignment(.trailing)
        .focused($focusedRowID, equals: row.id)
        .onSubmit { advanceFocus() }
        .disabled(isExcluded)
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(
              (row.hasValidationError || row.hasZeroValueError) ? .red : .clear,
              lineWidth: 1.5)
        )
        .helpWhenUnlocked(
          row.hasZeroValueError
            ? LocalizedStringKey(
              "Value cannot be 0. Exclude the asset instead if it is no longer held.")
            : nil
        )

      // Delete button for manualNew rows, padding for others
      if row.isNewRow {
        Button {
          viewModel.removeManualRow(rowID: row.id)
        } label: {
          Image(systemName: "trash")
            .foregroundStyle(.red)
        }
        .buttonStyle(.plain)
        .helpWhenUnlocked("Remove this manually added asset")
        .frame(width: 28)
      } else {
        Spacer()
          .frame(width: 28)
      }
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 4)
    .background(
      isUpdated
        ? Color.green.opacity(0.06)
        : Color.clear
    )
    .opacity(isExcluded ? 0.5 : 1.0)
    .accessibilityLabel(
      "\(row.assetName), \(row.platform), \(row.isUpdated ? "updated" : row.isPending ? "pending" : "excluded")"
    )
  }

  @ViewBuilder
  private func sourceBadge(for row: BulkEntryRow) -> some View {
    if row.source == .csv {
      Text("CSV")
        .font(.caption2)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(.blue.opacity(0.15), in: Capsule())
        .foregroundStyle(.blue)
    } else if row.source == .manualNew {
      Text("NEW")
        .font(.caption2)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(.green.opacity(0.15), in: Capsule())
        .foregroundStyle(.green)
    }
  }

  // MARK: - Category Picker

  private func categoryPicker(for row: BulkEntryRow) -> some View {
    CategoryNamePicker(
      categoryName: categoryNameBinding(for: row),
      cachedNames: $cachedCategoryNames
    )
  }

  private func loadCachedCategoryNames() {
    let descriptor = FetchDescriptor<Category>(
      sortBy: [SortDescriptor(\.displayOrder), SortDescriptor(\.name)])
    let categories = (try? modelContext.fetch(descriptor)) ?? []
    cachedCategoryNames = categories.map(\.name)
  }

  // MARK: - Bindings

  private func includeBinding(for row: BulkEntryRow) -> Binding<Bool> {
    Binding(
      get: { viewModel.rows.first(where: { $0.id == row.id })?.isIncluded ?? false },
      set: { _ in viewModel.toggleInclude(rowID: row.id) }
    )
  }

  private func bindingForRow(_ row: BulkEntryRow) -> Binding<String> {
    Binding(
      get: { viewModel.rows.first(where: { $0.id == row.id })?.newValueText ?? "" },
      set: { newValue in
        if let index = viewModel.rows.firstIndex(where: { $0.id == row.id }) {
          viewModel.rows[index].newValueText = newValue
        }
      }
    )
  }

  private func assetNameBinding(for row: BulkEntryRow) -> Binding<String> {
    Binding(
      get: { viewModel.rows.first(where: { $0.id == row.id })?.assetName ?? "" },
      set: { newValue in
        if let index = viewModel.rows.firstIndex(where: { $0.id == row.id }) {
          viewModel.rows[index].assetName = newValue
        }
      }
    )
  }

  private func currencyBinding(for row: BulkEntryRow) -> Binding<String> {
    Binding(
      get: { viewModel.rows.first(where: { $0.id == row.id })?.currency ?? "" },
      set: { newValue in
        if let index = viewModel.rows.firstIndex(where: { $0.id == row.id }) {
          viewModel.rows[index].currency = newValue
        }
      }
    )
  }

  private func categoryNameBinding(for row: BulkEntryRow) -> Binding<String> {
    Binding(
      get: { viewModel.rows.first(where: { $0.id == row.id })?.categoryName ?? "" },
      set: { newValue in
        if let index = viewModel.rows.firstIndex(where: { $0.id == row.id }) {
          viewModel.rows[index].categoryName = newValue.isEmpty ? nil : newValue
        }
      }
    )
  }

  // MARK: - Keyboard Navigation

  private func advanceFocus() {
    let includedRows = viewModel.platformGroups.flatMap(\.rows).filter(\.isIncluded)
    guard let currentIndex = includedRows.firstIndex(where: { $0.id == focusedRowID }) else {
      return
    }
    let nextIndex = currentIndex + 1
    if nextIndex < includedRows.count {
      focusedRowID = includedRows[nextIndex].id
    }
  }

  // MARK: - Save / Cancel

  private func handleSave() {
    if viewModel.pendingCount > 0 {
      showZeroPendingConfirmation = true
    } else {
      performSave()
    }
  }

  private func performSave() {
    do {
      let snapshot = try viewModel.saveSnapshot()
      onSave(snapshot)
    } catch {
      errorMessage = error.localizedDescription
      showError = true
    }
  }

  private func formatImportResult(
    _ result: CSVImportResult
  ) -> (title: String, message: String) {
    let title: String
    if result.hasErrors {
      title = String(localized: "Import Error", table: "Snapshot")
    } else if result.hasWarnings {
      title = String(localized: "Import Warning", table: "Snapshot")
    } else {
      title = String(localized: "CSV Import", table: "Snapshot")
    }

    var lines: [String] = []

    if result.matchedCount > 0 {
      lines.append(
        String(
          localized: "\(result.matchedCount) existing assets updated.",
          table: "Snapshot"))
    }
    if result.newCount > 0 {
      lines.append(
        String(
          localized: "\(result.newCount) new assets added.",
          table: "Snapshot"))
    }
    if result.totalImported == 0 && !result.hasErrors {
      lines.append(
        String(
          localized: "No assets were imported.",
          table: "Snapshot"))
    }

    for error in result.errors {
      lines.append(error)
    }
    for warning in result.parserWarnings {
      lines.append(warning)
    }

    if !result.platformMismatches.isEmpty {
      let names = result.platformMismatches.joined(separator: ", ")
      lines.append(
        String(
          localized:
            "\(result.platformMismatches.count) assets skipped (platform mismatch): \(names)",
          table: "Snapshot"))
    }
    if !result.currencyMismatches.isEmpty {
      let names = result.currencyMismatches.joined(separator: ", ")
      lines.append(
        String(
          localized:
            "\(result.currencyMismatches.count) assets skipped (currency mismatch): \(names)",
          table: "Snapshot"))
    }

    return (title: title, message: lines.joined(separator: "\n\n"))
  }

}

// MARK: - Category Name Picker

/// A lightweight picker for selecting or creating a category by name.
///
/// Unlike `CategoryPickerField`, this does not create `Category` objects
/// in the database. It stores category names as strings, deferring
/// database creation to snapshot save time.
private struct CategoryNamePicker: View {
  @Binding var categoryName: String
  @Binding var cachedNames: [String]

  @State private var showNewField = false
  @State private var newName = ""

  var body: some View {
    if showNewField {
      HStack(spacing: 2) {
        TextField("Category", text: $newName)
          .textFieldStyle(.roundedBorder)
          .font(.callout)
          .onSubmit { commitNew() }
        Button {
          commitNew()
        } label: {
          Image(systemName: "checkmark.circle.fill")
            .foregroundStyle(.green)
        }
        .buttonStyle(.plain)
        Button {
          showNewField = false
          newName = ""
        } label: {
          Image(systemName: "xmark.circle.fill")
            .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
      }
    } else {
      Picker("", selection: pickerBinding) {
        Text("None").tag("")
        ForEach(cachedNames, id: \.self) { name in
          Text(name).tag(name)
        }
        Divider()
        Text("New Category\u{2026}").tag("__new__")
      }
      .labelsHidden()
      .font(.callout)
    }
  }

  private var pickerBinding: Binding<String> {
    Binding(
      get: { categoryName },
      set: { newValue in
        if newValue == "__new__" {
          showNewField = true
          newName = ""
        } else {
          categoryName = newValue
        }
      }
    )
  }

  private func commitNew() {
    let trimmed = newName.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }

    // Case-insensitive match against existing names
    if let match = cachedNames.first(where: { $0.lowercased() == trimmed.lowercased() }) {
      categoryName = match
    } else {
      categoryName = trimmed
      cachedNames.append(trimmed)
      cachedNames.sort()
    }

    showNewField = false
    newName = ""
  }
}
