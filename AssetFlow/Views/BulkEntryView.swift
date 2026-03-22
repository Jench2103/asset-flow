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

import SwiftUI
import UniformTypeIdentifiers

/// Full-screen view for bulk snapshot entry with a platform-grouped table.
///
/// Displays all assets from the most recent snapshot, grouped by platform,
/// allowing the user to enter new values for each asset. Supports per-platform
/// CSV import and keyboard navigation between rows.
struct BulkEntryView: View {
  @State var viewModel: BulkEntryViewModel
  let onSave: (Snapshot) -> Void

  @FocusState private var focusedRowID: UUID?
  @State private var showCancelConfirmation = false
  @State private var showZeroPendingConfirmation = false
  @State private var csvImportPlatform: String?
  @State private var showError = false
  @State private var errorMessage = ""

  @Environment(\.dismiss) private var dismiss

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
            ContentUnavailableView(
              "No assets found",
              systemImage: "tray",
              description: Text("Import a CSV file to add assets.")
            )
          }
        }
        .padding()
      }
    }
    .fileImporter(
      isPresented: Binding(
        get: { csvImportPlatform != nil },
        set: { if !$0 { csvImportPlatform = nil } }
      ),
      allowedContentTypes: [.commaSeparatedText, .plainText]
    ) { result in
      guard let platform = csvImportPlatform,
        let url = try? result.get()
      else { return }
      if url.startAccessingSecurityScopedResource() {
        defer { url.stopAccessingSecurityScopedResource() }
        if let data = try? Data(contentsOf: url) {
          let errors = viewModel.importCSV(data: data, forPlatform: platform)
          if !errors.isEmpty {
            errorMessage = errors.joined(separator: "\n")
            showError = true
          }
        }
      }
    }
    .alert("Discard unsaved changes?", isPresented: $showCancelConfirmation) {
      Button("Discard", role: .destructive) { dismiss() }
      Button("Cancel", role: .cancel) {}
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
    }
    .alert("Error", isPresented: $showError) {
      Button("OK") {}
    } message: {
      Text(errorMessage)
    }
  }

  // MARK: - Toolbar

  private var toolbar: some View {
    HStack(spacing: 16) {
      Text("New Snapshot — \(viewModel.snapshotDate.settingsFormatted())")
        .font(.headline)

      Spacer()

      progressStats

      Button("Save Snapshot") {
        handleSave()
      }
      .buttonStyle(.borderedProminent)
      .disabled(!viewModel.canSave)
      .helpWhenUnlocked("Save the snapshot with entered values")

      Button("Cancel") {
        handleCancel()
      }
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

  // MARK: - Platform Section

  @ViewBuilder
  private func platformSection(
    _ group: (platform: String, rows: [BulkEntryRow])
  ) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      platformHeader(group)
      columnHeaders
      ForEach(group.rows) { row in
        assetEntryRow(row)
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
        csvImportPlatform = group.platform
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
    HStack(spacing: 0) {
      Text("Include")
        .frame(width: 60, alignment: .center)
      Text("Asset Name")
        .frame(minWidth: 150, alignment: .leading)
      Spacer()
      Text("Currency")
        .frame(width: 80, alignment: .center)
      Text("Previous Value")
        .frame(width: 140, alignment: .trailing)
      Text("New Value")
        .frame(width: 160, alignment: .trailing)
        .padding(.trailing, 4)
    }
    .font(.caption)
    .foregroundStyle(.secondary)
    .padding(.vertical, 4)
    .padding(.horizontal, 4)
    .background(.fill.quaternary)
  }

  // MARK: - Asset Entry Row

  @ViewBuilder
  private func assetEntryRow(_ row: BulkEntryRow) -> some View {
    let isExcluded = !row.isIncluded
    let isUpdated = row.isUpdated

    HStack(spacing: 0) {
      Toggle("", isOn: includeBinding(for: row))
        .labelsHidden()
        .frame(width: 60, alignment: .center)
        .helpWhenUnlocked("Include or exclude this asset from the snapshot")

      HStack(spacing: 6) {
        Text(row.assetName)
          .strikethrough(isExcluded)
        if row.source == .csv {
          Text("CSV")
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 1)
            .background(.blue.opacity(0.15), in: Capsule())
            .foregroundStyle(.blue)
        }
      }
      .frame(minWidth: 150, alignment: .leading)

      Spacer()

      Text(row.currency.uppercased())
        .font(.callout)
        .frame(width: 80, alignment: .center)

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
            .stroke(row.hasValidationError ? .red : .clear, lineWidth: 1.5)
        )
        .padding(.trailing, 4)
    }
    .padding(.vertical, 6)
    .padding(.horizontal, 4)
    .background(
      isUpdated
        ? Color.green.opacity(0.06)
        : Color.clear
    )
    .opacity(isExcluded ? 0.5 : 1.0)
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

  private func handleCancel() {
    let hasEnteredValues = viewModel.rows.contains { !$0.newValueText.isEmpty }
    if hasEnteredValues {
      showCancelConfirmation = true
    } else {
      dismiss()
    }
  }
}
