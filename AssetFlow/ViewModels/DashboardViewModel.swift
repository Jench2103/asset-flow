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

/// A resolved period with its begin and end snapshots.
private struct ResolvedPeriod {
  let beginSnapshot: Snapshot
  let endSnapshot: Snapshot
  var beginDate: Date { beginSnapshot.date }
  var endDate: Date { endSnapshot.date }
}

/// Data point for portfolio value or TWR history charts.
struct DashboardDataPoint {
  let date: Date
  let value: Decimal
}

/// Data for a recent snapshot row on the dashboard.
struct RecentSnapshotData {
  let date: Date
  let totalValue: Decimal
  let assetCount: Int
}

/// ViewModel for the Dashboard (home) screen.
///
/// Computes summary metrics, period performance, category allocations,
/// portfolio value history, TWR history, and recent snapshots.
@Observable
@MainActor
class DashboardViewModel {
  private let modelContext: ModelContext

  // MARK: - State

  /// Whether the dashboard has no data to show (empty state).
  var isEmpty: Bool = true

  /// Total portfolio value from latest snapshot.
  var totalPortfolioValue: Decimal = 0

  /// Date of the latest snapshot.
  var latestSnapshotDate: Date?

  /// Number of assets in the latest snapshot.
  var assetCount: Int = 0

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

  /// Per-category value at each snapshot, keyed by category name.
  var categoryValueHistory: [String: [DashboardDataPoint]] = [:]

  // MARK: - Private cached data

  private var allSnapshots: [Snapshot] = []
  private var sortedSnapshotsCache: [Snapshot] = []

  /// Total value per snapshot (built once per load cycle).
  private var snapshotTotalCache: [UUID: Decimal] = [:]

  /// Category breakdown per snapshot (built once per load cycle).
  private var categoryValuesCache: [UUID: [String: Decimal]] = [:]

  /// Modified Dietz returns per consecutive pair (built once per load cycle).
  private var cachedPeriodReturns: [Decimal?] = []

  /// Resolved periods for growth/return rate lookups (built once per load cycle).
  private var resolvedPeriodCache: [DashboardPeriod: ResolvedPeriod] = [:]

  /// Intermediate snapshots per period (built once per load cycle).
  private var intermediateSnapshotsCache: [DashboardPeriod: [Snapshot]] = [:]

  /// Display currency used when caches were built.
  private var cachedDisplayCurrency: String?

  // MARK: - Init

  init(modelContext: ModelContext) {
    self.modelContext = modelContext
  }

  // MARK: - Load Data

  /// Loads all dashboard data from the model context.
  ///
  /// Wraps the load in `withObservationTracking` so that any `@Observable`/`@Model`
  /// property change (e.g. currency, asset values, exchange rates) automatically
  /// triggers a reload.
  func loadData() {
    withObservationTracking {
      performLoadData()
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        self?.loadData()
      }
    }
  }

  private func performLoadData() {
    allSnapshots = fetchAllSnapshots()

    guard !allSnapshots.isEmpty else {
      isEmpty = true
      totalPortfolioValue = 0
      latestSnapshotDate = nil
      assetCount = 0
      cumulativeTWR = nil
      cagr = nil
      categoryAllocations = []
      portfolioValueHistory = []
      twrHistory = []
      categoryValueHistory = [:]
      recentSnapshots = []
      sortedSnapshotsCache = []
      snapshotTotalCache = [:]
      categoryValuesCache = [:]
      cachedPeriodReturns = []
      resolvedPeriodCache = [:]
      intermediateSnapshotsCache = [:]
      cachedDisplayCurrency = nil
      snapshotDates = []
      return
    }

    isEmpty = false
    let sortedSnapshots = allSnapshots.sorted { $0.date < $1.date }
    sortedSnapshotsCache = sortedSnapshots

    // Build caches once: categoryValues per snapshot, derive totals from sums
    let displayCurrency = SettingsService.shared.mainCurrency
    cachedDisplayCurrency = displayCurrency
    var totalCache: [UUID: Decimal] = [:]
    var catCache: [UUID: [String: Decimal]] = [:]
    for snapshot in sortedSnapshots {
      let catValues = CurrencyConversionService.categoryValues(
        for: snapshot, displayCurrency: displayCurrency, exchangeRate: snapshot.exchangeRate)
      catCache[snapshot.id] = catValues
      totalCache[snapshot.id] = catValues.values.reduce(0, +)
    }
    snapshotTotalCache = totalCache
    categoryValuesCache = catCache

    // Build period returns cache once
    if sortedSnapshots.count >= 2 {
      cachedPeriodReturns = computePeriodReturns(sortedSnapshots: sortedSnapshots)
    } else {
      cachedPeriodReturns = []
    }

    // Build resolved period cache once (avoids repeated findClosestSnapshot calls per render)
    var periodCache: [DashboardPeriod: ResolvedPeriod] = [:]
    for period in DashboardPeriod.allCases {
      if let resolved = buildResolvedPeriod(for: period, sortedSnapshots: sortedSnapshots) {
        periodCache[period] = resolved
      }
    }
    resolvedPeriodCache = periodCache

    // Build intermediate snapshots cache once (avoids repeated filter in returnRate)
    var intermediateCache: [DashboardPeriod: [Snapshot]] = [:]
    for (period, resolved) in periodCache {
      intermediateCache[period] = sortedSnapshots.filter {
        $0.date > resolved.beginDate && $0.date <= resolved.endDate
      }
    }
    intermediateSnapshotsCache = intermediateCache

    computeSummaryCards(sortedSnapshots: sortedSnapshots)
    computeCategoryAllocations(sortedSnapshots: sortedSnapshots)
    computePortfolioValueHistory(sortedSnapshots: sortedSnapshots)
    computeTWRHistory(sortedSnapshots: sortedSnapshots)
    computeCategoryValueHistory(sortedSnapshots: sortedSnapshots)
    computeRecentSnapshots(sortedSnapshots: sortedSnapshots)
    snapshotDates = sortedSnapshots.map(\.date)
  }

  // MARK: - Snapshot Dates

  /// All snapshot dates sorted ascending, for chart snapshot pickers.
  var snapshotDates: [Date] = []

  // MARK: - Category Allocations for Specific Date

  /// Returns category allocations for a specific snapshot date.
  ///
  /// Groups asset values by category for the snapshot matching the given date.
  /// Returns empty if no matching snapshot exists.
  func categoryAllocations(forSnapshotDate date: Date) -> [CategoryAllocationData] {
    guard let snapshot = sortedSnapshotsCache.first(where: { $0.date == date }) else {
      return []
    }
    return computeCategoryAllocationsForSnapshot(snapshot)
  }

  // MARK: - Period Performance

  /// Returns the cached resolved period for a given dashboard period.
  private func resolvePeriod(for period: DashboardPeriod) -> ResolvedPeriod? {
    resolvedPeriodCache[period]
  }

  /// Resolves a period to its begin and end snapshots using bidirectional lookback.
  ///
  /// Finds the closest snapshot to the lookback target date (in either direction),
  /// with no distance limit. When equidistant, prefers the earlier snapshot.
  /// Called once per period during `performLoadData()` to build `resolvedPeriodCache`.
  private func buildResolvedPeriod(
    for period: DashboardPeriod, sortedSnapshots: [Snapshot]
  ) -> ResolvedPeriod? {
    guard sortedSnapshots.count >= 2 else { return nil }
    guard let latestSnapshot = sortedSnapshots.last else { return nil }

    guard
      let lookbackDate = Calendar.current.date(
        byAdding: .month, value: -period.months, to: latestSnapshot.date)
    else { return nil }

    guard
      let beginSnapshot = findClosestSnapshot(
        to: lookbackDate, excluding: latestSnapshot, in: sortedSnapshots)
    else { return nil }

    return ResolvedPeriod(
      beginSnapshot: beginSnapshot, endSnapshot: latestSnapshot)
  }

  /// Growth rate for a given period (SPEC Section 10.3).
  ///
  /// Uses bidirectional lookback to find the closest snapshot to the target date.
  /// Returns nil if fewer than 2 snapshots exist.
  func growthRate(for period: DashboardPeriod) -> Decimal? {
    guard let resolved = resolvePeriod(for: period) else { return nil }

    let beginValue = snapshotTotal(for: resolved.beginSnapshot)
    let endValue = snapshotTotal(for: resolved.endSnapshot)

    return CalculationService.growthRate(beginValue: beginValue, endValue: endValue)
  }

  /// Modified Dietz return for a given period (SPEC Section 10.4).
  ///
  /// Uses the same bidirectional lookback as growthRate. Gathers intermediate cash
  /// flows from snapshots strictly after the begin snapshot through the latest.
  func returnRate(for period: DashboardPeriod) -> Decimal? {
    guard let resolved = resolvePeriod(for: period) else { return nil }

    let beginValue = snapshotTotal(for: resolved.beginSnapshot)
    let endValue = snapshotTotal(for: resolved.endSnapshot)

    let totalDays =
      Calendar.current.dateComponents(
        [.day], from: resolved.beginDate, to: resolved.endDate
      ).day ?? 0

    guard totalDays > 0 else { return nil }

    // Gather cash flows from snapshots strictly after begin through latest (inclusive)
    let displayCurrency =
      cachedDisplayCurrency ?? SettingsService.shared.mainCurrency
    let intermediateSnapshots = intermediateSnapshotsCache[period] ?? []

    var cashFlows: [(amount: Decimal, daysSinceStart: Int)] = []
    for snapshot in intermediateSnapshots {
      let netCashFlow = CurrencyConversionService.netCashFlow(
        for: snapshot, displayCurrency: displayCurrency, exchangeRate: snapshot.exchangeRate)
      if netCashFlow != 0 {
        let daysSinceStart =
          Calendar.current.dateComponents([.day], from: resolved.beginDate, to: snapshot.date).day
          ?? 0
        cashFlows.append((amount: netCashFlow, daysSinceStart: daysSinceStart))
      }
    }

    return CalculationService.modifiedDietzReturn(
      beginValue: beginValue, endValue: endValue,
      cashFlows: cashFlows, totalDays: totalDays)
  }

  /// Returns the actual date range for a resolved period.
  func periodDateRange(for period: DashboardPeriod) -> (begin: Date, end: Date)? {
    guard let resolved = resolvePeriod(for: period) else { return nil }
    return (begin: resolved.beginDate, end: resolved.endDate)
  }

  // MARK: - Private: Summary Cards

  private func computeSummaryCards(sortedSnapshots: [Snapshot]) {
    guard let latestSnapshot = sortedSnapshots.last else { return }

    totalPortfolioValue = snapshotTotal(for: latestSnapshot)
    latestSnapshotDate = latestSnapshot.date
    assetCount = (latestSnapshot.assetValues ?? []).count

    // Cumulative TWR — treat nil returns as 0% (identity) to match twrHistory
    if sortedSnapshots.count >= 2 {
      let product = cachedPeriodReturns.reduce(Decimal(1)) { acc, periodReturn in
        acc * (1 + (periodReturn ?? 0))
      }
      cumulativeTWR = product - 1
    } else {
      cumulativeTWR = nil
    }

    // CAGR
    if sortedSnapshots.count >= 2, let firstSnapshot = sortedSnapshots.first {
      let firstTotal = snapshotTotal(for: firstSnapshot)
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
    categoryAllocations = computeCategoryAllocationsForSnapshot(latestSnapshot)
  }

  /// Computes category allocation data for a single snapshot with currency conversion.
  private func computeCategoryAllocationsForSnapshot(
    _ snapshot: Snapshot
  ) -> [CategoryAllocationData] {
    let total = snapshotTotal(for: snapshot)
    guard total > 0 else { return [] }

    let catValues: [String: Decimal]
    if let cached = categoryValuesCache[snapshot.id] {
      catValues = cached
    } else {
      let currency =
        cachedDisplayCurrency ?? SettingsService.shared.mainCurrency
      catValues = CurrencyConversionService.categoryValues(
        for: snapshot, displayCurrency: currency, exchangeRate: snapshot.exchangeRate)
    }

    return
      catValues.map { name, value in
        let displayName = name.isEmpty ? "Uncategorized" : name
        return CategoryAllocationData(
          categoryName: displayName,
          value: value,
          percentage: CalculationService.categoryAllocation(
            categoryValue: value, totalValue: total)
        )
      }.sorted { $0.value > $1.value }
  }

  // MARK: - Private: Category Value History

  private func computeCategoryValueHistory(sortedSnapshots: [Snapshot]) {
    var result: [String: [DashboardDataPoint]] = [:]

    for snapshot in sortedSnapshots {
      guard let catValues = categoryValuesCache[snapshot.id] else { continue }

      for (categoryName, value) in catValues {
        let displayName = categoryName.isEmpty ? "Uncategorized" : categoryName
        result[displayName, default: []].append(
          DashboardDataPoint(date: snapshot.date, value: value))
      }
    }

    categoryValueHistory = result
  }

  // MARK: - Private: Portfolio Value History

  private func computePortfolioValueHistory(sortedSnapshots: [Snapshot]) {
    portfolioValueHistory = sortedSnapshots.map { snapshot in
      DashboardDataPoint(
        date: snapshot.date,
        value: snapshotTotal(for: snapshot)
      )
    }
  }

  // MARK: - Private: TWR History

  private func computeTWRHistory(sortedSnapshots: [Snapshot]) {
    guard sortedSnapshots.count >= 2 else {
      twrHistory = []
      return
    }

    // Start with 0% at the first snapshot (inception point)
    var history: [DashboardDataPoint] = [
      DashboardDataPoint(date: sortedSnapshots[0].date, value: 0)
    ]
    var cumulativeProduct = Decimal(1)

    for (index, periodReturn) in cachedPeriodReturns.enumerated() {
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
      RecentSnapshotData(
        date: snapshot.date,
        totalValue: snapshotTotal(for: snapshot),
        assetCount: (snapshot.assetValues ?? []).count
      )
    }
  }

  // MARK: - Private: Helpers

  private func fetchAllSnapshots() -> [Snapshot] {
    let descriptor = FetchDescriptor<Snapshot>(sortBy: [SortDescriptor(\.date)])
    return (try? modelContext.fetch(descriptor)) ?? []
  }

  private func snapshotTotal(for snapshot: Snapshot) -> Decimal {
    if let cached = snapshotTotalCache[snapshot.id] {
      return cached
    }
    let currency =
      cachedDisplayCurrency ?? SettingsService.shared.mainCurrency
    return CurrencyConversionService.totalValue(
      for: snapshot, displayCurrency: currency, exchangeRate: snapshot.exchangeRate)
  }

  /// Computes Modified Dietz returns for each consecutive pair of snapshots.
  private func computePeriodReturns(sortedSnapshots: [Snapshot]) -> [Decimal?] {
    var returns: [Decimal?] = []

    for idx in 1..<sortedSnapshots.count {
      let begin = sortedSnapshots[idx - 1]
      let end = sortedSnapshots[idx]

      let beginValue = snapshotTotal(for: begin)
      let endValue = snapshotTotal(for: end)

      let totalDays =
        Calendar.current.dateComponents(
          [.day], from: begin.date, to: end.date
        ).day ?? 0

      guard totalDays > 0 else {
        returns.append(nil)
        continue
      }

      // For consecutive pairs, only the end snapshot falls in (begin, end].
      let displayCurrency =
        cachedDisplayCurrency ?? SettingsService.shared.mainCurrency
      var cashFlows: [(amount: Decimal, daysSinceStart: Int)] = []
      let netCashFlow = CurrencyConversionService.netCashFlow(
        for: end, displayCurrency: displayCurrency, exchangeRate: end.exchangeRate)
      if netCashFlow != 0 {
        cashFlows.append((amount: netCashFlow, daysSinceStart: totalDays))
      }

      returns.append(
        CalculationService.modifiedDietzReturn(
          beginValue: beginValue, endValue: endValue,
          cashFlows: cashFlows, totalDays: totalDays))
    }

    return returns
  }

  /// Finds the closest snapshot to the target date in either direction.
  ///
  /// Uses absolute day distance with no distance limit. When equidistant,
  /// prefers the earlier snapshot.
  private func findClosestSnapshot(
    to targetDate: Date, excluding excluded: Snapshot, in snapshots: [Snapshot]
  ) -> Snapshot? {
    let candidates = snapshots.filter { $0.id != excluded.id }
    guard !candidates.isEmpty else { return nil }

    return candidates.min { lhs, rhs in
      let distLHS = abs(
        Calendar.current.dateComponents([.day], from: lhs.date, to: targetDate).day ?? 0)
      let distRHS = abs(
        Calendar.current.dateComponents([.day], from: rhs.date, to: targetDate).day ?? 0)
      if distLHS != distRHS {
        return distLHS < distRHS
      }
      // Tie-break: prefer earlier snapshot
      return lhs.date < rhs.date
    }
  }
}
