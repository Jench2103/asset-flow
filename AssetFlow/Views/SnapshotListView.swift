//
//  SnapshotListView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import SwiftData
import SwiftUI

/// Snapshot list view with creation workflow.
///
/// Displays all snapshots sorted by date (newest first) with totals,
/// asset counts, and platform indicators. Supports creating new snapshots
/// (empty or copy-from-latest) and deletion with confirmation.
struct SnapshotListView: View {
  @State private var viewModel: SnapshotListViewModel
  @Binding var selectedSnapshot: Snapshot?

  @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]

  @Binding var showNewSnapshotSheet: Bool
  @State private var rowDataMap: [UUID: SnapshotRowData] = [:]
  @State private var snapshotToDelete: Snapshot?
  @State private var showDeleteConfirmation = false
  @State private var expandedSections: Set<SnapshotTimeBucket> = Set(SnapshotTimeBucket.allCases)

  var onNavigateToImport: (() -> Void)?

  init(
    modelContext: ModelContext,
    selectedSnapshot: Binding<Snapshot?>,
    showNewSnapshotSheet: Binding<Bool> = .constant(false),
    onNavigateToImport: (() -> Void)? = nil
  ) {
    _viewModel = State(wrappedValue: SnapshotListViewModel(modelContext: modelContext))
    _selectedSnapshot = selectedSnapshot
    _showNewSnapshotSheet = showNewSnapshotSheet
    self.onNavigateToImport = onNavigateToImport
  }

  var body: some View {
    Group {
      if snapshots.isEmpty {
        emptyState
      } else {
        snapshotList
      }
    }
    .navigationTitle("Snapshots")
    .toolbar {
      ToolbarItem(placement: .automatic) {
        Button {
          showNewSnapshotSheet = true
        } label: {
          Image(systemName: "plus")
        }
        .help("Create a new snapshot")
        .accessibilityIdentifier("New Snapshot Button")
      }
    }
    .onAppear {
      reloadRowData()
    }
    .onChange(of: snapshots) {
      reloadRowData()
    }
    .sheet(isPresented: $showNewSnapshotSheet) {
      NewSnapshotSheet(viewModel: viewModel) { snapshot in
        reloadRowData()
        selectedSnapshot = snapshot
      }
    }
    .confirmationDialog(
      "Delete Snapshot",
      isPresented: $showDeleteConfirmation,
      presenting: snapshotToDelete
    ) { snapshot in
      Button("Delete", role: .destructive) {
        viewModel.deleteSnapshot(snapshot)
        if selectedSnapshot?.id == snapshot.id {
          selectedSnapshot = nil
        }
        reloadRowData()
      }
      Button("Cancel", role: .cancel) {}
    } message: { snapshot in
      let data = viewModel.confirmationData(for: snapshot)
      let dateStr = data.date.settingsFormatted()
      let assetCount = data.assetCount
      let cfCount = data.cashFlowCount
      Text(
        "Delete snapshot from \(dateStr)? This will remove all \(assetCount) asset values and \(cfCount) cash flow operations. This action cannot be undone."
      )
    }
  }

  // MARK: - Snapshot List

  private var groupedSnapshots: [(bucket: SnapshotTimeBucket, snapshots: [Snapshot])] {
    let grouped = Dictionary(grouping: snapshots) { SnapshotTimeBucket.bucket(for: $0.date) }
    return SnapshotTimeBucket.allCases.compactMap { bucket in
      guard let items = grouped[bucket], !items.isEmpty else { return nil }
      return (bucket: bucket, snapshots: items)
    }
  }

  private func sectionBinding(for bucket: SnapshotTimeBucket) -> Binding<Bool> {
    Binding(
      get: { expandedSections.contains(bucket) },
      set: { isExpanded in
        if isExpanded { expandedSections.insert(bucket) } else { expandedSections.remove(bucket) }
      }
    )
  }

  private var snapshotList: some View {
    List(selection: $selectedSnapshot) {
      ForEach(groupedSnapshots, id: \.bucket) { group in
        Section(isExpanded: sectionBinding(for: group.bucket)) {
          ForEach(group.snapshots) { snapshot in
            snapshotRow(snapshot)
              .tag(snapshot)
          }
        } header: {
          Text(group.bucket.localizedName)
        }
      }
    }
    .onDeleteCommand {
      deleteSelectedSnapshot()
    }
    .accessibilityIdentifier("Snapshot List")
  }

  private func deleteSelectedSnapshot() {
    guard let snapshot = selectedSnapshot else { return }
    snapshotToDelete = snapshot
    showDeleteConfirmation = true
  }

  private func snapshotRow(_ snapshot: Snapshot) -> some View {
    let rowData = rowDataMap[snapshot.id]

    return HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(snapshot.date.settingsFormatted())
          .font(.body)

        if let rowData = rowData {
          platformBadges(rowData: rowData)
        }
      }

      Spacer()

      HStack(spacing: 12) {
        if let rowData = rowData {
          Text(
            rowData.totalValue.formatted(
              currency: SettingsService.shared.mainCurrency)
          )
          .font(.body)
          .monospacedDigit()

          Text("\(rowData.assetCount)")
            .font(.caption)
            .foregroundStyle(.secondary)
            .padding(.horizontal, ChartConstants.badgePaddingH)
            .padding(.vertical, ChartConstants.badgePaddingV)
            .background(.quaternary)
            .clipShape(Capsule())
            .accessibilityLabel("\(rowData.assetCount) assets")
        }
      }
    }
    .contextMenu {
      Button("Delete", role: .destructive) {
        snapshotToDelete = snapshot
        showDeleteConfirmation = true
      }
    }
  }

  @ViewBuilder
  private func platformBadges(
    rowData: SnapshotRowData
  ) -> some View {
    let maxVisible = 3
    let allPlatforms = rowData.platforms
    let overflow = max(0, allPlatforms.count - maxVisible)

    HStack(spacing: 4) {
      ForEach(allPlatforms.prefix(maxVisible), id: \.self) { platform in
        Text(platform)
          .font(.caption2)
          .padding(.horizontal, ChartConstants.compactBadgePaddingH)
          .padding(.vertical, ChartConstants.compactBadgePaddingV)
          .background(.quaternary)
          .clipShape(Capsule())
      }

      if overflow > 0 {
        Text("+\(overflow)")
          .font(.caption2)
          .foregroundStyle(.secondary)
      }
    }
  }

  // MARK: - Empty State

  private var emptyState: some View {
    ContentUnavailableView {
      Label("No Snapshots", systemImage: "calendar")
    } description: {
      Text("No snapshots yet. Create your first snapshot or import a CSV to get started.")
    } actions: {
      Button("New Snapshot") {
        showNewSnapshotSheet = true
      }
      Button("Import CSV") {
        onNavigateToImport?()
      }
    }
  }

  // MARK: - Helpers

  private func reloadRowData() {
    rowDataMap = viewModel.loadAllSnapshotRowData()
  }
}

// MARK: - New Snapshot Sheet

private struct NewSnapshotSheet: View {
  let viewModel: SnapshotListViewModel
  let onCreate: (Snapshot) -> Void

  @Environment(\.dismiss) private var dismiss

  @Query(sort: \Snapshot.date) private var allSnapshots: [Snapshot]

  @FocusState private var focusedField: Field?
  enum Field { case date }

  @State private var snapshotDate = Date()
  @State private var copyFromLatest = false
  @State private var showError = false
  @State private var errorMessage = ""

  private var hasDateConflict: Bool {
    allSnapshots.contains(where: {
      Calendar.current.isDate($0.date, inSameDayAs: snapshotDate)
    })
  }

  var body: some View {
    NavigationStack {
      Form {
        DatePicker(
          "Snapshot Date",
          selection: $snapshotDate,
          in: ...Date(),
          displayedComponents: .date
        )
        .focused($focusedField, equals: .date)
        .accessibilityIdentifier("Snapshot Date Picker")

        if hasDateConflict {
          Label(
            "A snapshot already exists for \(snapshotDate.settingsFormatted()). Go to the Snapshots screen to view and edit it.",
            systemImage: "exclamationmark.triangle"
          )
          .font(.caption)
          .foregroundStyle(.orange)
        }

        Toggle("Copy from latest snapshot", isOn: $copyFromLatest)
          .disabled(!viewModel.canCopyFromLatest(for: snapshotDate))

        if !viewModel.canCopyFromLatest(for: snapshotDate) {
          Text("No prior snapshots available to copy from.")
            .font(.caption)
            .foregroundStyle(.secondary)
        }
      }
      .formStyle(.grouped)
      .navigationTitle("New Snapshot")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Create") {
            createSnapshot()
          }
          .disabled(hasDateConflict)
        }
      }
    }
    .frame(minWidth: 350, minHeight: 220)
    .onAppear { focusedField = .date }
    .alert("Error", isPresented: $showError) {
      Button("OK") {}
    } message: {
      Text(errorMessage)
    }
  }

  private func createSnapshot() {
    do {
      let snapshot = try viewModel.createSnapshot(
        date: snapshotDate, copyFromLatest: copyFromLatest)
      onCreate(snapshot)
      dismiss()
    } catch {
      errorMessage = error.localizedDescription
      showError = true
    }
  }
}

// MARK: - Previews

#Preview("Snapshot List") {
  NavigationStack {
    SnapshotListView(
      modelContext: PreviewContainer.container.mainContext,
      selectedSnapshot: .constant(nil)
    )
  }
}
