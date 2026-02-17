//
//  SnapshotListView.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import SwiftData
import SwiftUI

/// Snapshot list view with carry-forward indicators and creation workflow.
///
/// Displays all snapshots sorted by date (newest first) with composite totals,
/// asset counts, and platform indicators. Supports creating new snapshots
/// (empty or copy-from-latest) and deletion with confirmation.
struct SnapshotListView: View {
  @State private var viewModel: SnapshotListViewModel
  @Binding var selectedSnapshot: Snapshot?

  @Query(sort: \Snapshot.date, order: .reverse) private var snapshots: [Snapshot]

  @State private var showNewSnapshotSheet = false
  @State private var rowDataMap: [UUID: SnapshotRowData] = [:]
  @State private var snapshotToDelete: Snapshot?
  @State private var showDeleteConfirmation = false
  @State private var expandedSections: Set<SnapshotTimeBucket> = Set(SnapshotTimeBucket.allCases)

  var onNavigateToImport: (() -> Void)?

  init(
    modelContext: ModelContext,
    selectedSnapshot: Binding<Snapshot?>,
    onNavigateToImport: (() -> Void)? = nil
  ) {
    _viewModel = State(wrappedValue: SnapshotListViewModel(modelContext: modelContext))
    _selectedSnapshot = selectedSnapshot
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
            rowData.compositeTotal.formatted(
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
    let allDirect = rowData.directPlatforms
    let allCarried = rowData.carriedForwardPlatforms
    let totalCount = allDirect.count + allCarried.count
    let overflow = max(0, totalCount - maxVisible)

    HStack(spacing: 4) {
      ForEach(allDirect.prefix(maxVisible), id: \.self) { platform in
        Text(platform)
          .font(.caption2)
          .padding(.horizontal, ChartConstants.compactBadgePaddingH)
          .padding(.vertical, ChartConstants.compactBadgePaddingV)
          .background(.quaternary)
          .clipShape(Capsule())
      }

      let carriedSlots = max(0, maxVisible - allDirect.count)
      ForEach(allCarried.prefix(carriedSlots), id: \.self) { platform in
        HStack(spacing: 2) {
          Image(systemName: "arrow.uturn.forward")
            .font(.caption2)
          Text(platform)
            .font(.caption2)
        }
        .padding(.horizontal, ChartConstants.compactBadgePaddingH)
        .padding(.vertical, ChartConstants.compactBadgePaddingV)
        .background(.quaternary.opacity(0.5))
        .clipShape(Capsule())
        .foregroundStyle(.secondary)
        .italic()
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
    EmptyStateView(
      icon: "calendar",
      title: "No Snapshots",
      message: "No snapshots yet. Create your first snapshot or import a CSV to get started.",
      actions: [
        EmptyStateAction(label: "New Snapshot", isPrimary: false) {
          showNewSnapshotSheet = true
        },
        EmptyStateAction(label: "Import CSV", isPrimary: false) {
          onNavigateToImport?()
        },
      ]
    )
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
    VStack(spacing: 0) {
      Text("New Snapshot")
        .font(.headline)
        .padding(.top, 16)
        .padding(.horizontal)

      Form {
        DatePicker(
          "Snapshot Date",
          selection: $snapshotDate,
          in: ...Date(),
          displayedComponents: .date
        )
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

      HStack {
        Button("Cancel", role: .cancel) {
          dismiss()
        }
        .keyboardShortcut(.cancelAction)

        Spacer()

        Button("Create") {
          createSnapshot()
        }
        .keyboardShortcut(.defaultAction)
        .disabled(hasDateConflict)
      }
      .padding()
    }
    .frame(minWidth: 350, minHeight: 220)
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
