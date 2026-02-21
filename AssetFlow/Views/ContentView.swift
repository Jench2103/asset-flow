//
//  ContentView.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/18.
//

import SwiftData
import SwiftUI

// MARK: - Focused Value Keys

struct NewSnapshotActionKey: FocusedValueKey {
  typealias Value = () -> Void
}

struct ImportCSVActionKey: FocusedValueKey {
  typealias Value = () -> Void
}

extension FocusedValues {
  var newSnapshotAction: (() -> Void)? {
    get { self[NewSnapshotActionKey.self] }
    set { self[NewSnapshotActionKey.self] = newValue }
  }

  var importCSVAction: (() -> Void)? {
    get { self[ImportCSVActionKey.self] }
    set { self[ImportCSVActionKey.self] = newValue }
  }
}

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
  @State private var selectedPlatform: String?

  @State private var showNewSnapshotSheet = false
  @State private var importViewModel: ImportViewModel?
  @State private var pendingSection: SidebarSection?
  @State private var showDiscardConfirmation = false

  // Navigation history
  @State private var sectionHistory: [SidebarSection] = [.dashboard]
  @State private var historyIndex: Int = 0
  @State private var isNavigatingHistory = false

  var body: some View {
    NavigationSplitView(columnVisibility: .constant(.all)) {
      sidebar
        .navigationTitle("AssetFlow")
        .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 260)
        .toolbar(removing: .sidebarToggle)
    } detail: {
      detailPane
    }
    .frame(minWidth: 900, minHeight: 600)
    .focusedValue(\.newSnapshotAction) {
      pushHistory(.snapshots)
      showNewSnapshotSheet = true
    }
    .focusedValue(\.importCSVAction) { navigateToImport() }
    .toolbar {
      ToolbarItem(placement: .navigation) {
        Button(action: goBack) {
          Image(systemName: "chevron.left")
        }
        .disabled(!canGoBack)
        .help("Go back")
        .accessibilityIdentifier("Go Back Button")
      }
      ToolbarItem(placement: .navigation) {
        Button(action: goForward) {
          Image(systemName: "chevron.right")
        }
        .disabled(!canGoForward)
        .help("Go forward")
        .accessibilityIdentifier("Go Forward Button")
      }
    }
    .confirmationDialog(
      "Discard import?",
      isPresented: $showDiscardConfirmation
    ) {
      Button("Discard", role: .destructive) {
        importViewModel?.reset()
        if let pending = pendingSection {
          pushHistory(pending)
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
        pushHistory(.snapshots)
        selectedSnapshot = snapshot
        importViewModel?.importedSnapshot = nil
        importViewModel?.reset()
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
      Section("Overview") {
        Label(SidebarSection.dashboard.label, systemImage: SidebarSection.dashboard.systemImage)
          .tag(SidebarSection.dashboard)
      }
      Section("Portfolio") {
        ForEach(
          [SidebarSection.snapshots, .assets, .categories, .platforms], id: \.self
        ) { section in
          Label(section.label, systemImage: section.systemImage)
            .tag(section)
        }
      }
      Section("Tools") {
        ForEach([SidebarSection.rebalancing, .importCSV], id: \.self) { section in
          Label(section.label, systemImage: section.systemImage)
            .tag(section)
        }
      }
    }
  }

  /// Custom binding that intercepts sidebar selection changes to check for unsaved import data.
  private var sidebarBinding: Binding<SidebarSection?> {
    Binding(
      get: { selectedSection },
      set: { newSection in
        guard let newSection, newSection != selectedSection else { return }

        // Check if navigating away from import with unsaved changes
        if selectedSection == .importCSV,
          importViewModel?.hasUnsavedChanges == true
        {
          pendingSection = newSection
          showDiscardConfirmation = true
        } else {
          pushHistory(newSection)
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
        onNavigateToSnapshots: { pushHistory(.snapshots) },
        onNavigateToImport: { navigateToImport() },
        onSelectSnapshot: { date in
          navigateToSnapshotByDate(date)
        },
        onNavigateToCategory: { name in
          navigateToCategoryByName(name)
        }
      )

    case .snapshots:
      HStack(spacing: 0) {
        SnapshotListView(
          modelContext: modelContext,
          selectedSnapshot: $selectedSnapshot,
          showNewSnapshotSheet: $showNewSnapshotSheet,
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
          placeholderView("Select a snapshot", systemImage: "calendar")
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
          placeholderView("Select an asset", systemImage: "tray")
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
          placeholderView("Select a category", systemImage: "folder")
        }
      }

    case .platforms:
      HStack(spacing: 0) {
        PlatformListView(modelContext: modelContext, selectedPlatform: $selectedPlatform)
          .frame(minWidth: 250, idealWidth: 300)

        Divider()

        if let platform = selectedPlatform {
          PlatformDetailView(
            platformName: platform,
            modelContext: modelContext,
            onRename: { selectedPlatform = $0 }
          )
          .id(platform)
          .frame(maxWidth: .infinity)
        } else {
          placeholderView("Select a platform", systemImage: "building.columns")
        }
      }

    case .rebalancing:
      RebalancingView(modelContext: modelContext)

    case .importCSV:
      if let viewModel = importViewModel {
        ImportView(viewModel: viewModel)
      } else {
        ProgressView()
      }

    case nil:
      placeholderView("Select a section", systemImage: "sidebar.left")
    }
  }

  // MARK: - Helpers

  private func placeholderView(_ title: LocalizedStringKey, systemImage: String) -> some View {
    ContentUnavailableView(title, systemImage: systemImage)
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
    pushHistory(.importCSV)
  }

  /// Navigates to a category by looking up its name.
  /// Guards against "Uncategorized" which is not a real Category.
  private func navigateToCategoryByName(_ name: String) {
    guard name != "Uncategorized" else { return }

    let descriptor = FetchDescriptor<Category>()
    if let allCategories = try? modelContext.fetch(descriptor),
      let match = allCategories.first(where: {
        $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
      })
    {
      pushHistory(.categories)
      selectedCategory = match
    }
  }

  /// Navigates to a snapshot by looking up its date.
  private func navigateToSnapshotByDate(_ date: Date) {
    let targetDate = Calendar.current.startOfDay(for: date)
    let descriptor = FetchDescriptor<Snapshot>()
    if let allSnapshots = try? modelContext.fetch(descriptor),
      let match = allSnapshots.first(where: { $0.date == targetDate })
    {
      pushHistory(.snapshots)
      selectedSnapshot = match
    }
  }

  // MARK: - Navigation History

  private var canGoBack: Bool { historyIndex > 0 }
  private var canGoForward: Bool { historyIndex < sectionHistory.count - 1 }

  private func goBack() {
    guard canGoBack else { return }
    isNavigatingHistory = true
    historyIndex -= 1
    selectedSection = sectionHistory[historyIndex]
    isNavigatingHistory = false
  }

  private func goForward() {
    guard canGoForward else { return }
    isNavigatingHistory = true
    historyIndex += 1
    selectedSection = sectionHistory[historyIndex]
    isNavigatingHistory = false
  }

  private func pushHistory(_ section: SidebarSection) {
    guard !isNavigatingHistory else {
      selectedSection = section
      return
    }
    // Don't push if same as current
    guard section != selectedSection else {
      selectedSection = section
      return
    }
    // Truncate forward history
    if historyIndex < sectionHistory.count - 1 {
      sectionHistory = Array(sectionHistory.prefix(historyIndex + 1))
    }
    sectionHistory.append(section)
    historyIndex = sectionHistory.count - 1
    selectedSection = section
  }
}
