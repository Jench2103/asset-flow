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

  @State private var showRenameSheet = false
  @State private var renamingPlatform: String?

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
    .sheet(isPresented: $showRenameSheet) {
      if let platformName = renamingPlatform {
        RenamePlatformSheet(currentName: platformName) { newName in
          try viewModel.renamePlatform(from: platformName, to: newName)
          viewModel.loadPlatforms()
        }
      }
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
          .padding(.horizontal, 6)
          .padding(.vertical, 2)
          .background(.quaternary)
          .clipShape(Capsule())
      }
    }
    .contextMenu {
      Button {
        renamingPlatform = rowData.name
        showRenameSheet = true
      } label: {
        Label("Rename", systemImage: "pencil")
      }
      .accessibilityIdentifier("Rename Platform Button")
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    VStack(spacing: 12) {
      Spacer()
      Image(systemName: "building.columns")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("No Platforms")
        .font(.title3)
        .foregroundStyle(.secondary)
      Text(
        // swiftlint:disable:next line_length
        "No platforms yet. Platforms are created automatically when you import CSV data or create assets."
      )
      .font(.callout)
      .foregroundStyle(.tertiary)
      .multilineTextAlignment(.center)
      .padding(.horizontal)
      Spacer()
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: - Rename Platform Sheet

private struct RenamePlatformSheet: View {
  let currentName: String
  let onRename: (String) throws -> Void

  @Environment(\.dismiss) private var dismiss

  @State private var newName: String
  @State private var showError = false
  @State private var errorMessage = ""

  init(currentName: String, onRename: @escaping (String) throws -> Void) {
    self.currentName = currentName
    self.onRename = onRename
    _newName = State(wrappedValue: currentName)
  }

  var body: some View {
    VStack(spacing: 0) {
      Text("Rename Platform")
        .font(.headline)
        .padding(.top)

      Form {
        TextField("Platform Name", text: $newName)
          .accessibilityIdentifier("Platform Name Field")
      }
      .formStyle(.grouped)

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
      .padding()
    }
    .frame(minWidth: 350, minHeight: 150)
    .alert("Error", isPresented: $showError) {
      Button("OK") {}
    } message: {
      Text(errorMessage)
    }
  }

  private func renamePlatform() {
    do {
      try onRename(newName)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
      showError = true
    }
  }
}

// MARK: - Previews

#Preview("Platform List") {
  NavigationStack {
    PlatformListView(modelContext: PreviewContainer.container.mainContext)
  }
}
