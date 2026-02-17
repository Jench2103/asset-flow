//
//  PlatformListView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import SwiftData
import SwiftUI

/// Platform list view with rename sheet and empty state.
///
/// Displays all platforms derived from asset data with their asset count
/// and total value. Supports renaming via context menu.
struct PlatformListView: View {
  @State private var viewModel: PlatformListViewModel

  @State private var renamingPlatform: String?

  @State private var showError = false
  @State private var errorMessage = ""

  init(modelContext: ModelContext) {
    _viewModel = State(wrappedValue: PlatformListViewModel(modelContext: modelContext))
  }

  var body: some View {
    Group {
      if viewModel.platformRows.isEmpty {
        emptyState
      } else {
        platformList
      }
    }
    .navigationTitle("Platforms")
    .onAppear {
      viewModel.loadPlatforms()
    }
    .alert("Error", isPresented: $showError) {
      Button("OK") {}
    } message: {
      Text(errorMessage)
    }
  }

  // MARK: - Platform List

  private var platformList: some View {
    List {
      ForEach(viewModel.platformRows) { rowData in
        platformRow(rowData)
      }
    }
    .accessibilityIdentifier("Platform List")
  }

  private func platformRow(_ rowData: PlatformRowData) -> some View {
    HStack {
      Text(rowData.name)
        .font(.body)

      Spacer()

      HStack(spacing: 12) {
        Text(rowData.totalValue.formatted(currency: SettingsService.shared.mainCurrency))
          .font(.body)
          .monospacedDigit()

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
      Button {
        renamingPlatform = rowData.name
      } label: {
        Label("Rename", systemImage: "pencil")
      }
      .accessibilityIdentifier("Rename Platform Button")
    }
    .popover(
      isPresented: Binding(
        get: { renamingPlatform == rowData.name },
        set: { if !$0 { renamingPlatform = nil } }
      ),
      arrowEdge: .trailing
    ) {
      RenamePlatformPopover(currentName: rowData.name) { newName in
        try viewModel.renamePlatform(from: rowData.name, to: newName)
        viewModel.loadPlatforms()
      } onError: { message in
        errorMessage = message
        showError = true
      }
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    EmptyStateView(
      icon: "building.columns",
      title: "No Platforms",
      message:
        "No platforms yet. Platforms are created automatically "
        + "when you import CSV data or create assets."
    )
  }
}

// MARK: - Rename Platform Popover

private struct RenamePlatformPopover: View {
  let currentName: String
  let onRename: (String) throws -> Void
  let onError: (String) -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var newName: String

  init(
    currentName: String,
    onRename: @escaping (String) throws -> Void,
    onError: @escaping (String) -> Void
  ) {
    self.currentName = currentName
    self.onRename = onRename
    self.onError = onError
    _newName = State(wrappedValue: currentName)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text("Rename Platform")
        .font(.headline)

      TextField("Platform Name", text: $newName)
        .textFieldStyle(.roundedBorder)
        .accessibilityIdentifier("Platform Name Field")

      HStack {
        Button("Cancel", role: .cancel) {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Spacer()

        Button("Rename") {
          renamePlatform()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
      }
    }
    .frame(width: 280)
    .padding()
  }

  private func renamePlatform() {
    do {
      try onRename(newName)
      dismiss()
    } catch {
      dismiss()
      onError(error.localizedDescription)
    }
  }
}

// MARK: - Previews

#Preview("Platform List") {
  NavigationStack {
    PlatformListView(modelContext: PreviewContainer.container.mainContext)
  }
}
