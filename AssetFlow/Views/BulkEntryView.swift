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
  @State private var viewModel: BulkEntryViewModel
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

  init(viewModel: BulkEntryViewModel, onSave: @escaping (Snapshot) -> Void) {
    _viewModel = State(initialValue: viewModel)
    self.onSave = onSave
  }

  var body: some View {
    let duplicateIDs = viewModel.duplicateNameRowIDs

    VStack(spacing: 0) {
      toolbar
      Divider()
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: []) {
          ForEach(viewModel.platformGroups, id: \.platform) { group in
            platformSection(group, duplicateIDs: duplicateIDs)
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
          let formatted = importResult.formattedResult()
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

      BulkEntryProgressStats(
        updatedCount: viewModel.updatedCount,
        pendingCount: viewModel.pendingCount,
        excludedCount: viewModel.excludedCount
      )

      BulkEntryValidationWarnings(
        zeroValueCount: viewModel.zeroValueCount,
        hasInvalidNewRows: viewModel.hasInvalidNewRows,
        hasDuplicateNames: viewModel.hasDuplicateNames
      )

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
    .background(.ultraThinMaterial)
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
    _ group: (platform: String, rows: [BulkEntryRow]),
    duplicateIDs: Set<UUID>
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      platformHeader(group)
      BulkEntryColumnHeaders()
      ForEach(group.rows) { row in
        BulkEntryRowView(
          viewModel: viewModel,
          row: row,
          isDuplicate: duplicateIDs.contains(row.id),
          cachedCategoryNames: $cachedCategoryNames,
          focusedRowID: $focusedRowID,
          onAdvanceFocus: { advanceFocus() },
          onDelete: { viewModel.removeManualRow(rowID: row.id) }
        )
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

  // MARK: - Save

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

  private func loadCachedCategoryNames() {
    let descriptor = FetchDescriptor<Category>(
      sortBy: [SortDescriptor(\.displayOrder), SortDescriptor(\.name)])
    let categories = (try? modelContext.fetch(descriptor)) ?? []
    cachedCategoryNames = categories.map(\.name)
  }

}
