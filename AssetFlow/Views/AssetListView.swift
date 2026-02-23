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
  @Query private var assets: [Asset]

  @State private var showDeleteError = false
  @State private var deleteErrorMessage = ""

  init(modelContext: ModelContext, selectedAsset: Binding<Asset?>) {
    _viewModel = State(wrappedValue: AssetListViewModel(modelContext: modelContext))
    _selectedAsset = selectedAsset
  }

  private var assetsFingerprint: [String] {
    assets.map { asset in
      let latestValue = asset.snapshotAssetValues?
        .compactMap { sav -> (Date, Decimal)? in
          guard let d = sav.snapshot?.date else { return nil }
          return (d, sav.marketValue)
        }
        .max(by: { $0.0 < $1.0 })?
        .1
      return "\(asset.id)-\(asset.name)-\(asset.platform)"
        + "-\(String(describing: asset.category?.id))"
        + "-\(String(describing: latestValue))"
    }
  }

  var body: some View {
    Group {
      if viewModel.groups.isEmpty {
        emptyState
      } else {
        assetList
      }
    }
    .navigationTitle("Assets")
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Picker("Grouping", selection: $viewModel.groupingMode) {
          Text("By Platform").tag(AssetGroupingMode.byPlatform)
          Text("By Category").tag(AssetGroupingMode.byCategory)
        }
        .pickerStyle(.segmented)
        .help("Group assets by platform or category")
        .accessibilityIdentifier("Grouping Picker")
      }
    }
    .onAppear {
      viewModel.loadAssets()
    }
    .onChange(of: assetsFingerprint) {
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
        let effectiveCurrency =
          rowData.asset.currency.isEmpty
          ? SettingsService.shared.mainCurrency : rowData.asset.currency
        HStack(spacing: 4) {
          if effectiveCurrency != SettingsService.shared.mainCurrency {
            Text(effectiveCurrency.uppercased())
              .font(.caption2)
              .padding(.horizontal, 4)
              .padding(.vertical, 1)
              .background(.quaternary, in: Capsule())
          }
          Text(value.formatted(currency: effectiveCurrency))
            .font(.body)
            .monospacedDigit()
        }
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
    ContentUnavailableView {
      Label("No Assets", systemImage: "tray")
    } description: {
      Text("No assets yet. Assets are created automatically when you import CSV data.")
    }
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
