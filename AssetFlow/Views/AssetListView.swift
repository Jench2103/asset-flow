//
//  AssetListView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import SwiftData
import SwiftUI

/// Asset list view with grouping by platform or category.
///
/// Displays all assets grouped by the selected mode, with each row showing
/// the asset name, platform, category, and latest composite value.
struct AssetListView: View {
  @State private var viewModel: AssetListViewModel
  @Binding var selectedAsset: Asset?

  @State private var showDeleteError = false
  @State private var deleteErrorMessage = ""

  init(modelContext: ModelContext, selectedAsset: Binding<Asset?>) {
    _viewModel = State(wrappedValue: AssetListViewModel(modelContext: modelContext))
    _selectedAsset = selectedAsset
  }

  var body: some View {
    VStack(spacing: 0) {
      groupingPicker
        .padding(.horizontal)
        .padding(.vertical, 8)

      if viewModel.groups.isEmpty {
        emptyState
      } else {
        assetList
      }
    }
    .navigationTitle("Assets")
    .onAppear {
      viewModel.loadAssets()
    }
    .onChange(of: viewModel.groupingMode) {
      viewModel.loadAssets()
    }
    .onChange(of: selectedAsset) {
      viewModel.loadAssets()
    }
    .alert("Cannot Delete Asset", isPresented: $showDeleteError) {
      Button("OK") {}
    } message: {
      Text(deleteErrorMessage)
    }
  }

  // MARK: - Grouping Picker

  private var groupingPicker: some View {
    Picker("Grouping", selection: $viewModel.groupingMode) {
      Text("By Platform").tag(AssetGroupingMode.byPlatform)
      Text("By Category").tag(AssetGroupingMode.byCategory)
    }
    .pickerStyle(.segmented)
    .frame(maxWidth: 300)
    .accessibilityIdentifier("Grouping Picker")
  }

  // MARK: - Asset List

  private var assetList: some View {
    List(selection: $selectedAsset) {
      ForEach(viewModel.groups, id: \.name) { group in
        Section(group.name) {
          ForEach(group.assets, id: \.asset.id) { rowData in
            assetRow(rowData)
              .tag(rowData.asset)
          }
        }
      }
    }
    .onDeleteCommand {
      deleteSelectedAsset()
    }
    .accessibilityIdentifier("Asset List")
  }

  private func deleteSelectedAsset() {
    guard let asset = selectedAsset else { return }
    deleteAsset(asset)
  }

  private func assetRow(_ rowData: AssetRowData) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(rowData.asset.name)
          .font(.body)

        HStack(spacing: 8) {
          if !rowData.asset.platform.isEmpty {
            Text(rowData.asset.platform)
          }
          if let categoryName = rowData.asset.category?.name {
            Text(categoryName)
          }
        }
        .font(.caption)
        .foregroundStyle(.secondary)
      }

      Spacer()

      if let value = rowData.latestValue {
        Text(value.formatted(currency: SettingsService.shared.mainCurrency))
          .font(.body)
          .monospacedDigit()
      } else {
        Text("\u{2014}")
          .foregroundStyle(.secondary)
      }
    }
    .contextMenu {
      Button("Delete", role: .destructive) {
        deleteAsset(rowData.asset)
      }
      .disabled((rowData.asset.snapshotAssetValues?.count ?? 0) > 0)
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    EmptyStateView(
      icon: "tray",
      title: "No Assets",
      message: "No assets yet. Assets are created automatically when you import CSV data."
    )
  }

  // MARK: - Actions

  private func deleteAsset(_ asset: Asset) {
    do {
      try viewModel.deleteAsset(asset)
      if selectedAsset?.id == asset.id {
        selectedAsset = nil
      }
      viewModel.loadAssets()
    } catch {
      deleteErrorMessage = error.localizedDescription
      showDeleteError = true
    }
  }
}

// MARK: - Previews

#Preview("Asset List") {
  NavigationStack {
    AssetListView(
      modelContext: PreviewContainer.container.mainContext,
      selectedAsset: .constant(nil)
    )
  }
}
