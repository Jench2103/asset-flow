//
//  SnapshotListViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData

/// Error types for snapshot operations.
enum SnapshotError: LocalizedError, Equatable {
  case futureDateNotAllowed
  case dateAlreadyExists(Date)
  case assetAlreadyInSnapshot(String)
  case duplicateCashFlowDescription(String)

  var errorDescription: String? {
    switch self {
    case .futureDateNotAllowed:
      return String(
        localized: "Snapshot date cannot be in the future.", table: "Snapshot")

    case .dateAlreadyExists(let date):
      let dateStyle = MainActor.assumeIsolated { SettingsService.shared.dateFormat.dateStyle }
      let formatted = date.formatted(date: dateStyle, time: .omitted)
      return String(
        localized:
          "A snapshot already exists for \(formatted). Go to the Snapshots screen to view and edit it.",
        table: "Snapshot")

    case .assetAlreadyInSnapshot(let name):
      return String(
        localized:
          "'\(name)' already exists in this snapshot. Edit its value instead.",
        table: "Snapshot")

    case .duplicateCashFlowDescription(let description):
      return String(
        localized:
          "A cash flow operation with description '\(description)' already exists in this snapshot.",
        table: "Snapshot")
    }
  }
}

/// Data for a snapshot list row, including carry-forward information.
struct SnapshotRowData {
  let date: Date
  let compositeTotal: Decimal
  let directPlatforms: [String]
  let carriedForwardPlatforms: [String]
  let assetCount: Int
}

/// Data for snapshot deletion confirmation dialog.
struct SnapshotConfirmationData {
  let date: Date
  let assetCount: Int
  let cashFlowCount: Int
}

/// ViewModel for the Snapshots list screen.
///
/// Manages snapshot creation (empty or copy-from-latest), deletion,
/// and row data computation including carry-forward resolution.
@Observable
@MainActor
class SnapshotListViewModel {
  private let modelContext: ModelContext

  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  // MARK: - Creation

  /// Creates a new snapshot at the given date.
  ///
  /// - Parameters:
  ///   - date: The snapshot date (must be today or earlier, must not already exist).
  ///   - copyFromLatest: If true, copies all composite asset values from the most
  ///     recent prior snapshot, materializing carried-forward values as direct records.
  /// - Returns: The newly created Snapshot.
  /// - Throws: `SnapshotError.futureDateNotAllowed` or `SnapshotError.dateAlreadyExists`.
  @discardableResult
  func createSnapshot(date: Date, copyFromLatest: Bool) throws -> Snapshot {
    let normalizedDate = Calendar.current.startOfDay(for: date)
    let today = Calendar.current.startOfDay(for: Date())

    guard normalizedDate <= today else {
      throw SnapshotError.futureDateNotAllowed
    }

    // Check for existing snapshot on this date
    let existingDescriptor = FetchDescriptor<Snapshot>()
    let allSnapshots = try modelContext.fetch(existingDescriptor)
    if allSnapshots.contains(where: { $0.date == normalizedDate }) {
      throw SnapshotError.dateAlreadyExists(normalizedDate)
    }

    let snapshot = Snapshot(date: normalizedDate)
    modelContext.insert(snapshot)

    if copyFromLatest {
      copyCompositeValues(to: snapshot, allSnapshots: allSnapshots)
    }

    return snapshot
  }

  /// Whether "Copy from latest" is available for the given date.
  ///
  /// Returns true if at least one snapshot exists with a date before the selected date.
  func canCopyFromLatest(for date: Date) -> Bool {
    let normalizedDate = Calendar.current.startOfDay(for: date)
    let descriptor = FetchDescriptor<Snapshot>()
    let allSnapshots = (try? modelContext.fetch(descriptor)) ?? []
    return allSnapshots.contains(where: { $0.date < normalizedDate })
  }

  // MARK: - Deletion

  /// Deletes a snapshot and its cascaded relationships (asset values, cash flows).
  func deleteSnapshot(_ snapshot: Snapshot) {
    modelContext.delete(snapshot)
  }

  /// Returns confirmation data for the deletion dialog.
  func confirmationData(for snapshot: Snapshot) -> SnapshotConfirmationData {
    SnapshotConfirmationData(
      date: snapshot.date,
      assetCount: snapshot.assetValues?.count ?? 0,
      cashFlowCount: snapshot.cashFlowOperations?.count ?? 0
    )
  }

  // MARK: - Row Data

  /// Computes row data for all snapshots in a single batch, pre-fetching data once.
  func loadAllSnapshotRowData() -> [UUID: SnapshotRowData] {
    let allSnapshots = fetchAllSnapshots()
    let allAssetValues = fetchAllAssetValues()

    var result: [UUID: SnapshotRowData] = [:]
    for snapshot in allSnapshots {
      result[snapshot.id] = buildRowData(
        for: snapshot, allSnapshots: allSnapshots, allAssetValues: allAssetValues)
    }
    return result
  }

  /// Computes row data for a single snapshot, including carry-forward platform information.
  func snapshotRowData(for snapshot: Snapshot) -> SnapshotRowData {
    let allSnapshots = fetchAllSnapshots()
    let allAssetValues = fetchAllAssetValues()
    return buildRowData(
      for: snapshot, allSnapshots: allSnapshots, allAssetValues: allAssetValues)
  }

  private func buildRowData(
    for snapshot: Snapshot,
    allSnapshots: [Snapshot],
    allAssetValues: [SnapshotAssetValue]
  ) -> SnapshotRowData {
    let compositeValues = CarryForwardService.compositeValues(
      for: snapshot, allSnapshots: allSnapshots, allAssetValues: allAssetValues)

    let compositeTotal = compositeValues.reduce(Decimal(0)) { $0 + $1.marketValue }

    let directPlatforms = Array(
      Set(
        compositeValues
          .filter { !$0.isCarriedForward }
          .map { $0.asset.platform }
      )
    ).sorted()

    let carriedForwardPlatforms = Array(
      Set(
        compositeValues
          .filter { $0.isCarriedForward }
          .map { $0.asset.platform }
      )
    ).sorted()

    return SnapshotRowData(
      date: snapshot.date,
      compositeTotal: compositeTotal,
      directPlatforms: directPlatforms,
      carriedForwardPlatforms: carriedForwardPlatforms,
      assetCount: compositeValues.count
    )
  }

  // MARK: - Private Helpers

  private func fetchAllSnapshots() -> [Snapshot] {
    let descriptor = FetchDescriptor<Snapshot>(sortBy: [SortDescriptor(\.date)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  private func fetchAllAssetValues() -> [SnapshotAssetValue] {
    let descriptor = FetchDescriptor<SnapshotAssetValue>()
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  /// Copies all composite values from the most recent prior snapshot to the new snapshot.
  private func copyCompositeValues(to snapshot: Snapshot, allSnapshots: [Snapshot]) {
    let allAssetValues = fetchAllAssetValues()

    // Find the most recent snapshot before the new snapshot's date
    let priorSnapshots =
      allSnapshots
      .filter { $0.date < snapshot.date }
      .sorted { $0.date > $1.date }

    guard let latestPrior = priorSnapshots.first else { return }

    // Compute composite view for the latest prior snapshot
    let compositeValues = CarryForwardService.compositeValues(
      for: latestPrior,
      allSnapshots: allSnapshots,
      allAssetValues: allAssetValues
    )

    // Materialize all composite values as direct SnapshotAssetValues
    for compositeValue in compositeValues {
      let sav = SnapshotAssetValue(marketValue: compositeValue.marketValue)
      sav.snapshot = snapshot
      sav.asset = compositeValue.asset
      modelContext.insert(sav)
    }
  }
}
