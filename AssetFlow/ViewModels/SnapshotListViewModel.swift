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
      let formatted = MainActor.assumeIsolated { date.settingsFormatted() }
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

/// Relative time bucket for grouping snapshots in the list.
///
/// Boundaries are based on calendar month starts relative to the reference date.
/// Empty buckets are hidden at the view layer.
enum SnapshotTimeBucket: Int, CaseIterable, Hashable {
  case thisMonth
  case past3Months
  case past6Months
  case pastYear
  case older

  var localizedName: String {
    switch self {
    case .thisMonth: return String(localized: "This Month", table: "Snapshot")
    case .past3Months: return String(localized: "Previous 3 Months", table: "Snapshot")
    case .past6Months: return String(localized: "Previous 6 Months", table: "Snapshot")
    case .pastYear: return String(localized: "Previous Year", table: "Snapshot")
    case .older: return String(localized: "Older", table: "Snapshot")
    }
  }

  static func bucket(for date: Date, relativeTo now: Date = Date()) -> SnapshotTimeBucket {
    let calendar = Calendar.current
    guard
      let startOfCurrentMonth = calendar.date(
        from: calendar.dateComponents([.year, .month], from: now)),
      let threeMonthsAgo = calendar.date(
        byAdding: .month, value: -3, to: startOfCurrentMonth),
      let sixMonthsAgo = calendar.date(
        byAdding: .month, value: -6, to: startOfCurrentMonth),
      let oneYearAgo = calendar.date(
        byAdding: .year, value: -1, to: startOfCurrentMonth)
    else { return .older }

    if date >= startOfCurrentMonth { return .thisMonth }
    if date >= threeMonthsAgo { return .past3Months }
    if date >= sixMonthsAgo { return .past6Months }
    if date >= oneYearAgo { return .pastYear }

    return .older
  }
}

/// Data for a snapshot list row.
struct SnapshotRowData {
  let date: Date
  let totalValue: Decimal
  let platforms: [String]
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
/// and row data computation.
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
  ///   - copyFromLatest: If true, copies all direct asset values from the most
  ///     recent prior snapshot as new records.
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
      copyValuesFromLatest(to: snapshot, allSnapshots: allSnapshots)
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

  /// Computes row data for all snapshots in a single batch.
  func loadAllSnapshotRowData() -> [UUID: SnapshotRowData] {
    let allSnapshots = fetchAllSnapshots()

    var result: [UUID: SnapshotRowData] = [:]
    for snapshot in allSnapshots {
      result[snapshot.id] = buildRowData(for: snapshot)
    }
    return result
  }

  /// Computes row data for a single snapshot.
  func snapshotRowData(for snapshot: Snapshot) -> SnapshotRowData {
    buildRowData(for: snapshot)
  }

  private func buildRowData(for snapshot: Snapshot) -> SnapshotRowData {
    let directValues = snapshot.assetValues ?? []

    let totalValue = directValues.reduce(Decimal(0)) { $0 + $1.marketValue }

    let platforms = Array(
      Set(directValues.compactMap { $0.asset?.platform })
    ).sorted()

    return SnapshotRowData(
      date: snapshot.date,
      totalValue: totalValue,
      platforms: platforms,
      assetCount: directValues.count
    )
  }

  // MARK: - Private Helpers

  private func fetchAllSnapshots() -> [Snapshot] {
    let descriptor = FetchDescriptor<Snapshot>(sortBy: [SortDescriptor(\.date)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  /// Copies all direct asset values from the most recent prior snapshot to the new snapshot.
  private func copyValuesFromLatest(to snapshot: Snapshot, allSnapshots: [Snapshot]) {
    // Find the most recent snapshot before the new snapshot's date
    let priorSnapshots =
      allSnapshots
      .filter { $0.date < snapshot.date }
      .sorted { $0.date > $1.date }

    guard let latestPrior = priorSnapshots.first else { return }

    let latestValues = latestPrior.assetValues ?? []

    for priorSAV in latestValues {
      guard let asset = priorSAV.asset else { continue }
      let sav = SnapshotAssetValue(marketValue: priorSAV.marketValue)
      sav.snapshot = snapshot
      sav.asset = asset
      modelContext.insert(sav)
    }
  }
}
