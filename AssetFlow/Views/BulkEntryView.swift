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
  @State private var showZeroPendingConfirmation = false
  @State private var zeroPendingCount = 0
  @State private var csvImportPlatform: String = ""
  @State private var showCSVImporter = false
  @State private var showError = false
  @State private var errorMessage = ""
  @State private var showImportResult = false
  @State private var importResultTitle = ""
  @State private var importResultMessage = ""
  @State private var showCashFlowCSVImporter = false
  @State private var showCashFlowImportResult = false
  @State private var cashFlowImportResultTitle = ""
  @State private var cashFlowImportResultMessage = ""
  @State private var cachedCategoryNames: [String] = []

  init(viewModel: BulkEntryViewModel, onSave: @escaping (Snapshot) -> Void) {
    _viewModel = State(initialValue: viewModel)
    self.onSave = onSave
  }

  var body: some View {
    VStack(spacing: 0) {
      BulkEntryToolbar(
        viewModel: viewModel,
        onSave: { handleSave() })
      Divider()
      BulkEntryContentArea(
        viewModel: viewModel,
        cachedCategoryNames: $cachedCategoryNames,
        csvImportPlatform: $csvImportPlatform,
        showCSVImporter: $showCSVImporter,
        showCashFlowCSVImporter: $showCashFlowCSVImporter)
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
          viewModel.loadCSVForMapping(data: data, forPlatform: platform)
          if !viewModel.showColumnMappingSheet {
            // Auto-detected — show result immediately
            showLastImportResult()
          }
        }
      }
    }
    .sheet(isPresented: $viewModel.showColumnMappingSheet) {
      ColumnMappingSheet(
        rawHeaders: viewModel.pendingRawHeaders,
        schema: .assetWithoutPlatform,
        sampleRows: viewModel.pendingSampleRows,
        initialMapping: viewModel.pendingPartialMapping,
        onConfirm: { mapping in
          _ = viewModel.confirmColumnMapping(mapping)
          showLastImportResult()
        },
        onCancel: {
          viewModel.showColumnMappingSheet = false
        }
      )
    }
    .alert(
      String(
        localized:
          "\(zeroPendingCount) assets will be saved with a value of 0. Continue?",
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
    .alert(
      String(localized: "Unable to Save Snapshot", table: "Snapshot"),
      isPresented: $showError
    ) {
      Button("OK") {}
    } message: {
      Text(errorMessage)
    }
    .alert(importResultTitle, isPresented: $showImportResult) {
      Button("OK") {}
    } message: {
      Text(importResultMessage)
    }
    .fileImporter(
      isPresented: $showCashFlowCSVImporter,
      allowedContentTypes: [.commaSeparatedText, .plainText]
    ) { result in
      guard let url = try? result.get() else { return }
      if url.startAccessingSecurityScopedResource() {
        defer { url.stopAccessingSecurityScopedResource() }
        if let data = try? Data(contentsOf: url) {
          viewModel.loadCashFlowCSVForMapping(data: data)
          if !viewModel.showCashFlowColumnMappingSheet {
            showLastCashFlowImportResult()
          }
        }
      }
    }
    .sheet(isPresented: $viewModel.showCashFlowColumnMappingSheet) {
      ColumnMappingSheet(
        rawHeaders: viewModel.pendingCashFlowRawHeaders,
        schema: .cashFlow,
        sampleRows: viewModel.pendingCashFlowSampleRows,
        initialMapping: viewModel.pendingCashFlowPartialMapping,
        onConfirm: { mapping in
          _ = viewModel.confirmCashFlowColumnMapping(mapping)
          showLastCashFlowImportResult()
        },
        onCancel: {
          viewModel.showCashFlowColumnMappingSheet = false
        }
      )
    }
    .alert(cashFlowImportResultTitle, isPresented: $showCashFlowImportResult) {
      Button("OK") {}
    } message: {
      Text(cashFlowImportResultMessage)
    }
  }

  // MARK: - Save

  private func handleSave() {
    let pending = viewModel.pendingCount
    if pending > 0 {
      zeroPendingCount = pending
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

  private func showLastImportResult() {
    guard let importResult = viewModel.lastImportResult else { return }
    let formatted = importResult.formattedResult()
    importResultTitle = formatted.title
    importResultMessage = formatted.message
    showImportResult = true
    viewModel.lastImportResult = nil
  }

  private func showLastCashFlowImportResult() {
    guard let importResult = viewModel.lastCashFlowImportResult else { return }
    let formatted = importResult.formattedResult()
    cashFlowImportResultTitle = formatted.title
    cashFlowImportResultMessage = formatted.message
    showCashFlowImportResult = true
    viewModel.lastCashFlowImportResult = nil
  }

}
