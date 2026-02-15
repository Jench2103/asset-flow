//
//  ContentView.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/18.
//

import SwiftData
import SwiftUI

// MARK: - SidebarSection

/// Sidebar navigation sections for the main app window.
enum SidebarSection: String, CaseIterable, Identifiable {
  case dashboard
  case snapshots
  case assets
  case categories
  case platforms
  case rebalancing
  case importCSV

  var id: String { rawValue }

  var label: String {
    switch self {
    case .dashboard: return String(localized: "Dashboard")
    case .snapshots: return String(localized: "Snapshots")
    case .assets: return String(localized: "Assets")
    case .categories: return String(localized: "Categories")
    case .platforms: return String(localized: "Platforms")
    case .rebalancing: return String(localized: "Rebalancing")
    case .importCSV: return String(localized: "Import CSV")
    }
  }

  var systemImage: String {
    switch self {
    case .dashboard: return "chart.bar"
    case .snapshots: return "calendar"
    case .assets: return "tray"
    case .categories: return "folder"
    case .platforms: return "building.columns"
    case .rebalancing: return "chart.bar.doc.horizontal"
    case .importCSV: return "square.and.arrow.down"
    }
  }
}

// MARK: - ContentView

/// Root navigation shell with sidebar and detail pane.
///
/// Provides a 7-section sidebar (Dashboard, Snapshots, Assets, Categories,
/// Platforms, Rebalancing, Import CSV) with list-detail splits for Snapshots,
/// Assets, and Categories. Manages import discard confirmation and post-import
/// navigation to the created snapshot.
struct ContentView: View {
  @Environment(\.modelContext) private var modelContext

  @State private var selectedSection: SidebarSection? = .dashboard
  @State private var selectedSnapshot: Snapshot?
  @State private var selectedAsset: Asset?
  @State private var selectedCategory: Category?

  @State private var importViewModel: ImportViewModel?
  @State private var pendingSection: SidebarSection?
  @State private var showDiscardConfirmation = false
  @State private var dashboardRefreshID = UUID()

  var body: some View {
    NavigationSplitView {
      sidebar
        .navigationTitle("AssetFlow")
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
    } detail: {
      detailPane
    }
    .frame(minWidth: 900, minHeight: 600)
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button {
          navigateToImport()
        } label: {
          Label("Import CSV", systemImage: "square.and.arrow.down")
        }
      }
    }
    .confirmationDialog(
      "Discard import?",
      isPresented: $showDiscardConfirmation
    ) {
      Button("Discard", role: .destructive) {
        importViewModel?.reset()
        if let pending = pendingSection {
          selectedSection = pending
          pendingSection = nil
        }
      }
      Button("Cancel", role: .cancel) {
        pendingSection = nil
      }
    } message: {
      Text("The selected file has not been imported yet.")
    }
    .onChange(of: importViewModel?.importedSnapshot?.id) { _, newValue in
      if newValue != nil, let snapshot = importViewModel?.importedSnapshot {
        selectedSection = .snapshots
        selectedSnapshot = snapshot
        importViewModel?.importedSnapshot = nil
      }
    }
    .onChange(of: selectedSection) { _, newValue in
      if newValue == .dashboard {
        dashboardRefreshID = UUID()
      }
    }
    .onAppear {
      if importViewModel == nil {
        importViewModel = ImportViewModel(modelContext: modelContext)
      }
    }
  }

  // MARK: - Sidebar

  private var sidebar: some View {
    List(selection: sidebarBinding) {
      ForEach(SidebarSection.allCases) { section in
        Label(section.label, systemImage: section.systemImage)
          .tag(section)
      }
    }
  }

  /// Custom binding that intercepts sidebar selection changes to check for unsaved import data.
  private var sidebarBinding: Binding<SidebarSection?> {
    Binding(
      get: { selectedSection },
      set: { newSection in
        guard newSection != selectedSection else { return }

        // Check if navigating away from import with unsaved changes
        if selectedSection == .importCSV,
          importViewModel?.hasUnsavedChanges == true
        {
          pendingSection = newSection
          showDiscardConfirmation = true
        } else {
          selectedSection = newSection
        }
      }
    )
  }

  // MARK: - Detail Pane

  @ViewBuilder
  private var detailPane: some View {
    switch selectedSection {
    case .dashboard:
      DashboardView(
        modelContext: modelContext,
        onNavigateToSnapshots: { selectedSection = .snapshots },
        onNavigateToImport: { navigateToImport() },
        onSelectSnapshot: { date in
          navigateToSnapshotByDate(date)
        }
      )
      .id(dashboardRefreshID)

    case .snapshots:
      HStack(spacing: 0) {
        SnapshotListView(
          modelContext: modelContext,
          selectedSnapshot: $selectedSnapshot,
          onNavigateToImport: { navigateToImport() }
        )
        .frame(minWidth: 250, idealWidth: 300)

        Divider()

        if let snapshot = selectedSnapshot {
          SnapshotDetailView(
            snapshot: snapshot,
            modelContext: modelContext,
            onDelete: {
              selectedSnapshot = nil
            }
          )
          .id(snapshot.id)
          .frame(maxWidth: .infinity)
        } else {
          placeholderText("Select a snapshot")
        }
      }

    case .assets:
      HStack(spacing: 0) {
        AssetListView(
          modelContext: modelContext,
          selectedAsset: $selectedAsset
        )
        .frame(minWidth: 250, idealWidth: 300)

        Divider()

        if let asset = selectedAsset {
          AssetDetailView(
            asset: asset,
            modelContext: modelContext,
            onDelete: {
              selectedAsset = nil
            }
          )
          .id(asset.id)
          .frame(maxWidth: .infinity)
        } else {
          placeholderText("Select an asset")
        }
      }

    case .categories:
      HStack(spacing: 0) {
        CategoryListView(
          modelContext: modelContext,
          selectedCategory: $selectedCategory
        )
        .frame(minWidth: 250, idealWidth: 300)

        Divider()

        if let category = selectedCategory {
          CategoryDetailView(
            category: category,
            modelContext: modelContext,
            onDelete: {
              selectedCategory = nil
            }
          )
          .id(category.id)
          .frame(maxWidth: .infinity)
        } else {
          placeholderText("Select a category")
        }
      }

    case .platforms:
      PlatformListView(modelContext: modelContext)

    case .rebalancing:
      RebalancingView(modelContext: modelContext)

    case .importCSV:
      if let viewModel = importViewModel {
        ImportView(viewModel: viewModel)
      } else {
        ProgressView()
      }

    case nil:
      placeholderText("Select a section")
    }
  }

  // MARK: - Helpers

  private func placeholderText(_ text: String) -> some View {
    Text(text)
      .font(.title2)
      .foregroundStyle(.secondary)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }

  /// Navigates to the import section, checking for unsaved changes if already there.
  private func navigateToImport() {
    // If already on import with unsaved changes, offer to discard and restart
    if selectedSection == .importCSV,
      importViewModel?.hasUnsavedChanges == true
    {
      pendingSection = .importCSV
      showDiscardConfirmation = true
      return
    }

    // If already on import without unsaved changes, nothing to do
    if selectedSection == .importCSV { return }

    // Navigate to import
    selectedSection = .importCSV
  }

  /// Navigates to a snapshot by looking up its date.
  private func navigateToSnapshotByDate(_ date: Date) {
    let targetDate = Calendar.current.startOfDay(for: date)
    let descriptor = FetchDescriptor<Snapshot>()
    if let allSnapshots = try? modelContext.fetch(descriptor),
      let match = allSnapshots.first(where: { $0.date == targetDate })
    {
      selectedSection = .snapshots
      selectedSnapshot = match
    }
  }
}
