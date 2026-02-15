//
//  DashboardViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData

/// Performance period for growth and return rate calculations.
enum DashboardPeriod: CaseIterable {
  case oneMonth
  case threeMonths
  case oneYear

  /// Number of months to look back.
  var months: Int {
    switch self {
    case .oneMonth: return 1
    case .threeMonths: return 3
    case .oneYear: return 12
    }
  }
}

/// Data point for portfolio value or TWR history charts.
struct DashboardDataPoint {
  let date: Date
  let value: Decimal
}

/// Data for a recent snapshot row on the dashboard.
struct RecentSnapshotData {
  let date: Date
  let compositeTotal: Decimal
  let assetCount: Int
}

/// ViewModel for the Dashboard (home) screen.
///
/// Computes summary metrics, period performance, category allocations,
/// portfolio value history, TWR history, and recent snapshots.
/// All portfolio-level metrics use composite values (with carry-forward).
@Observable
@MainActor
class DashboardViewModel {
  private let modelContext: ModelContext

  // MARK: - State

  /// Whether the dashboard has no data to show (empty state).
  var isEmpty: Bool = true

  /// Total portfolio value from latest composite snapshot.
  var totalPortfolioValue: Decimal = 0

  /// Date of the latest snapshot.
  var latestSnapshotDate: Date?

  /// Number of assets in the latest composite snapshot.
  var assetCount: Int = 0

  /// Absolute value change from previous to latest snapshot.
  var valueChangeAbsolute: Decimal?

  /// Percentage value change from previous to latest snapshot.
  var valueChangePercentage: Decimal?

  /// Cumulative TWR since first snapshot.
  var cumulativeTWR: Decimal?

  /// CAGR since first snapshot.
  var cagr: Decimal?

  /// Category allocation data for the latest snapshot.
  var categoryAllocations: [CategoryAllocationData] = []

  /// Portfolio value at each snapshot (sorted by date ascending).
  var portfolioValueHistory: [DashboardDataPoint] = []

  /// Cumulative TWR at each snapshot (sorted by date ascending, starts from 2nd snapshot).
  var twrHistory: [DashboardDataPoint] = []

  /// Most recent 5 snapshots (newest first).
  var recentSnapshots: [RecentSnapshotData] = []

  // MARK: - Private cached data

  private var allSnapshots: [Snapshot] = []
  private var sortedSnapshotsCache: [Snapshot] = []
  private var allAssetValues: [SnapshotAssetValue] = []

  // MARK: - Init

  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  // MARK: - Load Data

  /// Loads all dashboard data from the model context.
  func loadData() {
    allSnapshots = fetchAllSnapshots()
    allAssetValues = fetchAllAssetValues()

    guard !allSnapshots.isEmpty else {
      isEmpty = true
      totalPortfolioValue = 0
      latestSnapshotDate = nil
      assetCount = 0
      valueChangeAbsolute = nil
      valueChangePercentage = nil
      cumulativeTWR = nil
      cagr = nil
      categoryAllocations = []
      portfolioValueHistory = []
      twrHistory = []
      recentSnapshots = []
      sortedSnapshotsCache = []
      return
    }

    isEmpty = false
    let sortedSnapshots = allSnapshots.sorted { $0.date < $1.date }
    sortedSnapshotsCache = sortedSnapshots

    computeSummaryCards(sortedSnapshots: sortedSnapshots)
    computeCategoryAllocations(sortedSnapshots: sortedSnapshots)
    computePortfolioValueHistory(sortedSnapshots: sortedSnapshots)
    computeTWRHistory(sortedSnapshots: sortedSnapshots)
    computeRecentSnapshots(sortedSnapshots: sortedSnapshots)
  }

  // MARK: - Period Performance

  /// Growth rate for a given period (SPEC Section 10.3).
  ///
  /// Finds the most recent snapshot on or before the lookback date.
  /// Returns nil if no such snapshot exists, or if it's more than 14 days
  /// before the lookback target date.
  func growthRate(for period: DashboardPeriod) -> Decimal? {
    guard sortedSnapshotsCache.count >= 2 else { return nil }
    guard let latestSnapshot = sortedSnapshotsCache.last else { return nil }

    guard
      let lookbackDate = Calendar.current.date(
        byAdding: .month, value: -period.months, to: latestSnapshot.date)
    else { return nil }

    guard
      let beginSnapshot = findSnapshotForLookback(
        targetDate: lookbackDate, sortedSnapshots: sortedSnapshotsCache,
        excludingLatest: latestSnapshot)
    else { return nil }

    let beginValue = compositeTotal(for: beginSnapshot)
    let endValue = compositeTotal(for: latestSnapshot)

    return CalculationService.growthRate(beginValue: beginValue, endValue: endValue)
  }

  /// Modified Dietz return for a given period (SPEC Section 10.4).
  ///
  /// Uses the same lookback logic as growthRate. Gathers intermediate cash flows
  /// from snapshots strictly after the begin snapshot through the latest.
  func returnRate(for period: DashboardPeriod) -> Decimal? {
    guard sortedSnapshotsCache.count >= 2 else { return nil }
    guard let latestSnapshot = sortedSnapshotsCache.last else { return nil }

    guard
      let lookbackDate = Calendar.current.date(
        byAdding: .month, value: -period.months, to: latestSnapshot.date)
    else { return nil }

    guard
      let beginSnapshot = findSnapshotForLookback(
        targetDate: lookbackDate, sortedSnapshots: sortedSnapshotsCache,
        excludingLatest: latestSnapshot)
    else { return nil }

    let beginValue = compositeTotal(for: beginSnapshot)
    let endValue = compositeTotal(for: latestSnapshot)

    let totalDays =
      Calendar.current.dateComponents(
        [.day], from: beginSnapshot.date, to: latestSnapshot.date
      ).day ?? 0

    guard totalDays > 0 else { return nil }

    // Gather cash flows from snapshots strictly after begin through latest (inclusive)
    let intermediateSnapshots = sortedSnapshotsCache.filter {
      $0.date > beginSnapshot.date && $0.date <= latestSnapshot.date
    }

    var cashFlows: [(amount: Decimal, daysSinceStart: Int)] = []
    for snapshot in intermediateSnapshots {
      let netCashFlow = (snapshot.cashFlowOperations ?? []).reduce(Decimal(0)) { $0 + $1.amount }
      if netCashFlow != 0 {
        let daysSinceStart =
          Calendar.current.dateComponents([.day], from: beginSnapshot.date, to: snapshot.date).day
          ?? 0
        cashFlows.append((amount: netCashFlow, daysSinceStart: daysSinceStart))
      }
    }

    return CalculationService.modifiedDietzReturn(
      beginValue: beginValue, endValue: endValue,
      cashFlows: cashFlows, totalDays: totalDays)
  }

  // MARK: - Private: Summary Cards

  private func computeSummaryCards(sortedSnapshots: [Snapshot]) {
    guard let latestSnapshot = sortedSnapshots.last else { return }
    let latestCompositeValues = CarryForwardService.compositeValues(
      for: latestSnapshot, allSnapshots: sortedSnapshots, allAssetValues: allAssetValues)

    totalPortfolioValue = latestCompositeValues.reduce(Decimal(0)) { $0 + $1.marketValue }
    latestSnapshotDate = latestSnapshot.date
    assetCount = latestCompositeValues.count

    // Value change from previous snapshot
    if sortedSnapshots.count >= 2 {
      let previousSnapshot = sortedSnapshots[sortedSnapshots.count - 2]
      let previousTotal = compositeTotal(for: previousSnapshot)

      valueChangeAbsolute = totalPortfolioValue - previousTotal
      valueChangePercentage = CalculationService.growthRate(
        beginValue: previousTotal, endValue: totalPortfolioValue)
    } else {
      valueChangeAbsolute = nil
      valueChangePercentage = nil
    }

    // Cumulative TWR — treat nil returns as 0% (identity) to match twrHistory
    if sortedSnapshots.count >= 2 {
      let periodReturns = computePeriodReturns(sortedSnapshots: sortedSnapshots)
      let product = periodReturns.reduce(Decimal(1)) { acc, periodReturn in
        acc * (1 + (periodReturn ?? 0))
      }
      cumulativeTWR = product - 1
    } else {
      cumulativeTWR = nil
    }

    // CAGR
    if sortedSnapshots.count >= 2, let firstSnapshot = sortedSnapshots.first {
      let firstTotal = compositeTotal(for: firstSnapshot)
      let days =
        Calendar.current.dateComponents(
          [.day], from: firstSnapshot.date, to: latestSnapshot.date
        ).day ?? 0
      let years = Double(days) / 365.25
      cagr = CalculationService.cagr(
        beginValue: firstTotal, endValue: totalPortfolioValue, years: years)
    } else {
      cagr = nil
    }
  }

  // MARK: - Private: Category Allocations

  private func computeCategoryAllocations(sortedSnapshots: [Snapshot]) {
    guard let latestSnapshot = sortedSnapshots.last else {
      categoryAllocations = []
      return
    }

    let compositeValues = CarryForwardService.compositeValues(
      for: latestSnapshot, allSnapshots: sortedSnapshots, allAssetValues: allAssetValues)

    let total = compositeValues.reduce(Decimal(0)) { $0 + $1.marketValue }
    guard total > 0 else {
      categoryAllocations = []
      return
    }

    var categoryValues: [String: Decimal] = [:]
    for cv in compositeValues {
      let categoryName = cv.asset.category?.name ?? "Uncategorized"
      categoryValues[categoryName, default: 0] += cv.marketValue
    }

    categoryAllocations =
      categoryValues.map { name, value in
        CategoryAllocationData(
          categoryName: name,
          value: value,
          percentage: CalculationService.categoryAllocation(
            categoryValue: value, totalValue: total)
        )
      }.sorted { $0.value > $1.value }
  }

  // MARK: - Private: Portfolio Value History

  private func computePortfolioValueHistory(sortedSnapshots: [Snapshot]) {
    portfolioValueHistory = sortedSnapshots.map { snapshot in
      DashboardDataPoint(
        date: snapshot.date,
        value: compositeTotal(for: snapshot)
      )
    }
  }

  // MARK: - Private: TWR History

  private func computeTWRHistory(sortedSnapshots: [Snapshot]) {
    guard sortedSnapshots.count >= 2 else {
      twrHistory = []
      return
    }

    let periodReturns = computePeriodReturns(sortedSnapshots: sortedSnapshots)

    var history: [DashboardDataPoint] = []
    var cumulativeProduct = Decimal(1)

    for (index, periodReturn) in periodReturns.enumerated() {
      if let returnValue = periodReturn {
        cumulativeProduct *= (1 + returnValue)
      }
      let snapshotDate = sortedSnapshots[index + 1].date
      history.append(
        DashboardDataPoint(
          date: snapshotDate,
          value: cumulativeProduct - 1
        )
      )
    }

    twrHistory = history
  }

  // MARK: - Private: Recent Snapshots

  private func computeRecentSnapshots(sortedSnapshots: [Snapshot]) {
    let newestFirst = sortedSnapshots.reversed()
    recentSnapshots = Array(newestFirst.prefix(5)).map { snapshot in
      let compositeValues = CarryForwardService.compositeValues(
        for: snapshot, allSnapshots: sortedSnapshots, allAssetValues: allAssetValues)
      return RecentSnapshotData(
        date: snapshot.date,
        compositeTotal: compositeValues.reduce(Decimal(0)) { $0 + $1.marketValue },
        assetCount: compositeValues.count
      )
    }
  }

  // MARK: - Private: Helpers

  private func fetchAllSnapshots() -> [Snapshot] {
    let descriptor = FetchDescriptor<Snapshot>(sortBy: [SortDescriptor(\.date)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  private func fetchAllAssetValues() -> [SnapshotAssetValue] {
    let descriptor = FetchDescriptor<SnapshotAssetValue>()
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  private func compositeTotal(for snapshot: Snapshot) -> Decimal {
    CarryForwardService.compositeTotalValue(
      for: snapshot, allSnapshots: allSnapshots, allAssetValues: allAssetValues)
  }

  /// Computes Modified Dietz returns for each consecutive pair of snapshots.
  private func computePeriodReturns(sortedSnapshots: [Snapshot]) -> [Decimal?] {
    var returns: [Decimal?] = []

    for idx in 1..<sortedSnapshots.count {
      let begin = sortedSnapshots[idx - 1]
      let end = sortedSnapshots[idx]

      let beginValue = compositeTotal(for: begin)
      let endValue = compositeTotal(for: end)

      let totalDays =
        Calendar.current.dateComponents(
          [.day], from: begin.date, to: end.date
        ).day ?? 0

      guard totalDays > 0 else {
        returns.append(nil)
        continue
      }

      // Cash flows from snapshots strictly after begin through end (inclusive)
      let intermediateSnapshots = allSnapshots.filter {
        $0.date > begin.date && $0.date <= end.date
      }

      var cashFlows: [(amount: Decimal, daysSinceStart: Int)] = []
      for snapshot in intermediateSnapshots {
        let netCashFlow = (snapshot.cashFlowOperations ?? []).reduce(Decimal(0)) {
          $0 + $1.amount
        }
        if netCashFlow != 0 {
          let daysSinceStart =
            Calendar.current.dateComponents([.day], from: begin.date, to: snapshot.date).day ?? 0
          cashFlows.append((amount: netCashFlow, daysSinceStart: daysSinceStart))
        }
      }

      returns.append(
        CalculationService.modifiedDietzReturn(
          beginValue: beginValue, endValue: endValue,
          cashFlows: cashFlows, totalDays: totalDays))
    }

    return returns
  }

  /// Finds the most recent snapshot on or before the target lookback date.
  /// Returns nil if none exists or if the found snapshot is more than 14 days
  /// before the target date (SPEC Section 10.3/10.4 lookback tolerance).
  private func findSnapshotForLookback(
    targetDate: Date, sortedSnapshots: [Snapshot], excludingLatest: Snapshot
  ) -> Snapshot? {
    let candidates = sortedSnapshots.filter {
      $0.date <= targetDate && $0.id != excludingLatest.id
    }
    guard let closest = candidates.last else { return nil }

    let daysDifference =
      Calendar.current.dateComponents(
        [.day], from: closest.date, to: targetDate
      ).day ?? 0

    guard daysDifference <= 14 else { return nil }

    return closest
  }
}
