//
//  DashboardViewModelTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("DashboardViewModel Tests")
@MainActor
struct DashboardViewModelTests {

  // MARK: - Test Helpers

  private struct TestContext {
    let container: ModelContainer
    let context: ModelContext
  }

  private func createTestContext() -> TestContext {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    return TestContext(container: container, context: context)
  }

  private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar.current.date(from: components)!
  }

  /// Creates a snapshot with assets and optional cash flows.
  @discardableResult
  private func createSnapshot(
    in context: ModelContext,
    date: Date,
    assets: [(name: String, platform: String, value: Decimal, category: AssetFlow.Category?)],
    cashFlows: [(description: String, amount: Decimal)] = []
  ) -> Snapshot {
    let snapshot = Snapshot(date: date)
    context.insert(snapshot)

    for assetData in assets {
      // Find or create asset
      let descriptor = FetchDescriptor<Asset>()
      let allAssets = (try? context.fetch(descriptor)) ?? []
      let normalizedName = assetData.name.trimmingCharacters(in: .whitespaces).lowercased()
      let normalizedPlatform = assetData.platform.trimmingCharacters(in: .whitespaces).lowercased()

      let asset =
        allAssets.first(where: {
          $0.normalizedName == normalizedName
            && $0.normalizedPlatform == normalizedPlatform
        })
        ?? {
          let a = Asset(name: assetData.name, platform: assetData.platform)
          context.insert(a)
          return a
        }()

      if let cat = assetData.category {
        asset.category = cat
      }

      let sav = SnapshotAssetValue(marketValue: assetData.value)
      sav.snapshot = snapshot
      sav.asset = asset
      context.insert(sav)
    }

    for cfData in cashFlows {
      let cf = CashFlowOperation(cashFlowDescription: cfData.description, amount: cfData.amount)
      cf.snapshot = snapshot
      context.insert(cf)
    }

    return snapshot
  }

  // MARK: - Empty State

  @Test("Empty state when no snapshots exist")
  func emptyState() {
    let tc = createTestContext()
    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    #expect(viewModel.isEmpty)
    #expect(viewModel.totalPortfolioValue == 0)
    #expect(viewModel.latestSnapshotDate == nil)
    #expect(viewModel.assetCount == 0)
    #expect(viewModel.cumulativeTWR == nil)
    #expect(viewModel.cagr == nil)
    #expect(viewModel.recentSnapshots.isEmpty)
  }

  // MARK: - Summary Cards

  @Test("Total portfolio value from stored values in latest snapshot")
  func totalPortfolioValueFromDirectValues() {
    let tc = createTestContext()

    // Snapshot 1: Platform A has asset worth 100,000
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )

    // Snapshot 2: Only BTC on Coinbase — AAPL is NOT included (no carry-forward)
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 2, day: 1),
      assets: [("BTC", "Coinbase", 50_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    // Total = only direct values in latest snapshot = 50,000
    #expect(viewModel.totalPortfolioValue == 50_000)
  }

  @Test("Latest snapshot date is correct")
  func latestSnapshotDate() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 10_000, nil)]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 6, day: 15),
      assets: [("AAPL", "Firstrade", 12_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    #expect(viewModel.latestSnapshotDate == makeDate(year: 2025, month: 6, day: 15))
  }

  @Test("Asset count from latest snapshot direct values only")
  func assetCount() {
    let tc = createTestContext()

    // Two assets on different platforms
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [
        ("AAPL", "Firstrade", 10_000, nil),
        ("BTC", "Coinbase", 5_000, nil),
      ]
    )

    // Only update Firstrade — BTC is NOT carried forward
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 2, day: 1),
      assets: [("AAPL", "Firstrade", 12_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    // Only AAPL (direct) in latest snapshot = 1
    #expect(viewModel.assetCount == 1)
  }

  @Test("Value change from previous snapshot")
  func valueChange() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 2, day: 1),
      assets: [("AAPL", "Firstrade", 110_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    #expect(viewModel.valueChangeAbsolute == 10_000)
    #expect(viewModel.valueChangePercentage != nil)
    // 10,000 / 100,000 = 0.10
    let pct = try! #require(viewModel.valueChangePercentage)
    #expect(abs(pct - Decimal(string: "0.1")!) < Decimal(string: "0.001")!)
  }

  @Test("Value change is nil when only one snapshot")
  func valueChangeNilWithOneSnapshot() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    #expect(viewModel.valueChangeAbsolute == nil)
    #expect(viewModel.valueChangePercentage == nil)
  }

  // MARK: - Cumulative TWR and CAGR

  @Test("Cumulative TWR with multiple snapshots and no cash flows")
  func cumulativeTWRNoCashFlows() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 2, day: 1),
      assets: [("AAPL", "Firstrade", 110_000, nil)]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 3, day: 1),
      assets: [("AAPL", "Firstrade", 121_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    let twr = try! #require(viewModel.cumulativeTWR)
    // Period 1: (110,000 - 100,000) / 100,000 = 0.10
    // Period 2: (121,000 - 110,000) / 110,000 = 0.10
    // TWR = (1.10) * (1.10) - 1 = 0.21
    #expect(abs(twr - Decimal(string: "0.21")!) < Decimal(string: "0.01")!)
  }

  @Test("TWR is nil with only one snapshot")
  func twrNilWithOneSnapshot() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    #expect(viewModel.cumulativeTWR == nil)
    #expect(viewModel.cagr == nil)
  }

  @Test("CAGR calculation with two snapshots")
  func cagrWithTwoSnapshots() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2024, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 110_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    let cagr = try! #require(viewModel.cagr)
    // CAGR = (110,000 / 100,000) ^ (1/1) - 1 = 0.10
    #expect(abs(cagr - Decimal(string: "0.1")!) < Decimal(string: "0.01")!)
  }

  @Test("Cumulative TWR and twrHistory are consistent when a period has nil return")
  func cumulativeTWRConsistentWithHistoryOnNilPeriods() {
    let tc = createTestContext()

    // Snapshot 1: zero value — Modified Dietz will return nil for this → next period
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 0, nil)]
    )

    // Snapshot 2: now has value
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 2, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )

    // Snapshot 3: grew to 110,000
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 3, day: 1),
      assets: [("AAPL", "Firstrade", 110_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    // twrHistory treats nil return as 0% (identity), so:
    //   Period 1 (Jan→Feb): nil → treated as 0%  → cumulative = (1+0) - 1 = 0
    //   Period 2 (Feb→Mar): 10% → cumulative = (1+0)(1+0.10) - 1 = 0.10
    // cumulativeTWR should match the last twrHistory point
    let lastHistoryValue = viewModel.twrHistory.last?.value
    #expect(lastHistoryValue != nil)
    #expect(viewModel.cumulativeTWR == lastHistoryValue)
  }

  // MARK: - Period Performance: Growth Rate

  @Test("Growth rate for a given period")
  func growthRateForPeriod() {
    let tc = createTestContext()

    // Create a snapshot 3 months ago (on or before the 3M lookback target)
    let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
    let startOf3MonthsAgo = Calendar.current.startOfDay(for: threeMonthsAgo)
    createSnapshot(
      in: tc.context,
      date: startOf3MonthsAgo,
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )

    // Create latest snapshot today
    let today = Calendar.current.startOfDay(for: Date())
    createSnapshot(
      in: tc.context,
      date: today,
      assets: [("AAPL", "Firstrade", 110_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    // 3M growth uses the 3-month-ago snapshot as beginning
    let growth3M = viewModel.growthRate(for: .threeMonths)
    #expect(growth3M != nil)
    // growth = (110,000 - 100,000) / 100,000 = 0.10
    if let g = growth3M {
      #expect(abs(g - Decimal(string: "0.1")!) < Decimal(string: "0.01")!)
    }
  }

  @Test("Growth rate returns nil when no snapshot within lookback window")
  func growthRateNilOutsideLookback() {
    let tc = createTestContext()

    // Snapshot very old - more than 14 days before 1M lookback target
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2020, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )

    let today = Calendar.current.startOfDay(for: Date())
    createSnapshot(
      in: tc.context,
      date: today,
      assets: [("AAPL", "Firstrade", 110_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    // 1M growth: lookback target is ~30 days ago, but closest prior is 5+ years ago
    // That's >14 days before the target, so N/A
    #expect(viewModel.growthRate(for: .oneMonth) == nil)
  }

  // MARK: - Period Performance: Return Rate (Modified Dietz)

  @Test("Return rate for a period with cash flows")
  func returnRateWithCashFlows() {
    let tc = createTestContext()

    let threeMonthsAgo = Calendar.current.date(byAdding: .month, value: -3, to: Date())!
    let startOf3MonthsAgo = Calendar.current.startOfDay(for: threeMonthsAgo)
    createSnapshot(
      in: tc.context,
      date: startOf3MonthsAgo,
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )

    // Intermediate snapshot with cash flow
    let sixWeeksAgo = Calendar.current.date(byAdding: .day, value: -42, to: Date())!
    let startOf6WeeksAgo = Calendar.current.startOfDay(for: sixWeeksAgo)
    createSnapshot(
      in: tc.context,
      date: startOf6WeeksAgo,
      assets: [("AAPL", "Firstrade", 130_000, nil)],
      cashFlows: [("Deposit", 20_000)]
    )

    let today = Calendar.current.startOfDay(for: Date())
    createSnapshot(
      in: tc.context,
      date: today,
      assets: [("AAPL", "Firstrade", 140_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    // Return rate should be non-nil for 3M period
    let returnRate = viewModel.returnRate(for: .threeMonths)
    #expect(returnRate != nil)
  }

  @Test("Return rate returns nil when only one snapshot")
  func returnRateNilWithOneSnapshot() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    #expect(viewModel.returnRate(for: .oneMonth) == nil)
    #expect(viewModel.returnRate(for: .threeMonths) == nil)
    #expect(viewModel.returnRate(for: .oneYear) == nil)
  }

  // MARK: - Category Allocation

  @Test("Category allocation for latest snapshot")
  func categoryAllocation() {
    let tc = createTestContext()

    let equities = Category(name: "Equities")
    let bonds = Category(name: "Bonds")
    tc.context.insert(equities)
    tc.context.insert(bonds)

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [
        ("AAPL", "Firstrade", 75_000, equities),
        ("AGG", "Firstrade", 25_000, bonds),
      ]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    let allocations = viewModel.categoryAllocations
    #expect(allocations.count == 2)

    let equityAlloc = allocations.first { $0.categoryName == "Equities" }
    #expect(equityAlloc != nil)
    #expect(equityAlloc?.value == 75_000)
    // 75,000 / 100,000 * 100 = 75
    #expect(equityAlloc?.percentage == 75)
  }

  @Test("Uncategorized assets shown in allocation")
  func uncategorizedInAllocation() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    let allocations = viewModel.categoryAllocations
    #expect(allocations.count == 1)
    #expect(allocations.first?.categoryName == "Uncategorized")
    #expect(allocations.first?.percentage == 100)
  }

  // MARK: - Portfolio Value History

  @Test("Portfolio value history includes all snapshots")
  func portfolioValueHistory() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 2, day: 1),
      assets: [("AAPL", "Firstrade", 110_000, nil)]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 3, day: 1),
      assets: [("AAPL", "Firstrade", 120_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    let history = viewModel.portfolioValueHistory
    #expect(history.count == 3)
    // Should be sorted by date ascending
    #expect(history[0].date == makeDate(year: 2025, month: 1, day: 1))
    #expect(history[0].value == 100_000)
    #expect(history[2].value == 120_000)
  }

  // MARK: - TWR History

  @Test("TWR history shows cumulative return at each snapshot")
  func twrHistory() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 2, day: 1),
      assets: [("AAPL", "Firstrade", 110_000, nil)]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 3, day: 1),
      assets: [("AAPL", "Firstrade", 121_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    let history = viewModel.twrHistory
    // TWR history starts from the second snapshot
    #expect(history.count == 2)
    // First TWR point: 10% cumulative
    #expect(abs(history[0].value - Decimal(string: "0.1")!) < Decimal(string: "0.01")!)
    // Second TWR point: 21% cumulative
    #expect(abs(history[1].value - Decimal(string: "0.21")!) < Decimal(string: "0.01")!)
  }

  @Test("TWR history is empty with fewer than 2 snapshots")
  func twrHistoryEmptyWithOneSnapshot() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    #expect(viewModel.twrHistory.isEmpty)
  }

  // MARK: - Recent Snapshots

  @Test("Recent snapshots returns last 5 newest first")
  func recentSnapshots() {
    let tc = createTestContext()

    for month in 1...7 {
      createSnapshot(
        in: tc.context,
        date: makeDate(year: 2025, month: month, day: 1),
        assets: [("AAPL", "Firstrade", Decimal(month) * 10_000, nil)]
      )
    }

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    let recent = viewModel.recentSnapshots
    #expect(recent.count == 5)
    // Newest first
    #expect(recent[0].date == makeDate(year: 2025, month: 7, day: 1))
    #expect(recent[4].date == makeDate(year: 2025, month: 3, day: 1))
  }

  @Test("Recent snapshots includes total value from direct SAVs only")
  func recentSnapshotsIncludeTotal() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [
        ("AAPL", "Firstrade", 100_000, nil),
        ("BTC", "Coinbase", 50_000, nil),
      ]
    )

    // Snapshot 2 only updates Firstrade — BTC not included (no carry-forward)
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 2, day: 1),
      assets: [("AAPL", "Firstrade", 110_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    let recent = viewModel.recentSnapshots
    #expect(recent.count == 2)
    // Latest: only direct SAVs = 110,000
    #expect(recent[0].totalValue == 110_000)
  }

  // MARK: - Period Enum

  @Test("Period enum provides correct lookback months")
  func periodLookbackMonths() {
    #expect(DashboardPeriod.oneMonth.months == 1)
    #expect(DashboardPeriod.threeMonths.months == 3)
    #expect(DashboardPeriod.oneYear.months == 12)
  }

  // MARK: - Snapshot Dates

  @Test("snapshotDates returns all dates sorted ascending")
  func snapshotDatesSortedAscending() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 3, day: 1),
      assets: [("AAPL", "Firstrade", 120_000, nil)]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 2, day: 1),
      assets: [("AAPL", "Firstrade", 110_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    #expect(viewModel.snapshotDates.count == 3)
    #expect(viewModel.snapshotDates[0] == makeDate(year: 2025, month: 1, day: 1))
    #expect(viewModel.snapshotDates[1] == makeDate(year: 2025, month: 2, day: 1))
    #expect(viewModel.snapshotDates[2] == makeDate(year: 2025, month: 3, day: 1))
  }

  @Test("snapshotDates is empty when no snapshots")
  func snapshotDatesEmptyWhenNoSnapshots() {
    let tc = createTestContext()
    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()
    #expect(viewModel.snapshotDates.isEmpty)
  }

  // MARK: - Category Allocations for Specific Snapshot Date

  @Test(
    "categoryAllocations(forSnapshotDate:) returns correct allocations for a historical snapshot")
  func categoryAllocationsForHistoricalSnapshot() {
    let tc = createTestContext()

    let equities = Category(name: "Equities")
    let bonds = Category(name: "Bonds")
    tc.context.insert(equities)
    tc.context.insert(bonds)

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [
        ("AAPL", "Firstrade", 60_000, equities),
        ("AGG", "Firstrade", 40_000, bonds),
      ]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 2, day: 1),
      assets: [
        ("AAPL", "Firstrade", 80_000, equities),
        ("AGG", "Firstrade", 20_000, bonds),
      ]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    // Check allocations for the first snapshot (60/40 split)
    let allocations = viewModel.categoryAllocations(
      forSnapshotDate: makeDate(year: 2025, month: 1, day: 1))
    #expect(allocations.count == 2)

    let equityAlloc = allocations.first { $0.categoryName == "Equities" }
    #expect(equityAlloc?.percentage == 60)

    let bondAlloc = allocations.first { $0.categoryName == "Bonds" }
    #expect(bondAlloc?.percentage == 40)
  }

  @Test("categoryAllocations(forSnapshotDate:) returns empty for non-existent date")
  func categoryAllocationsForNonExistentDate() {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    let allocations = viewModel.categoryAllocations(
      forSnapshotDate: makeDate(year: 2099, month: 1, day: 1))
    #expect(allocations.isEmpty)
  }

  // MARK: - Category Value History

  @Test("categoryValueHistory contains one series per category plus Uncategorized")
  func categoryValueHistoryPerCategory() {
    let tc = createTestContext()

    let equities = Category(name: "Equities")
    tc.context.insert(equities)

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [
        ("AAPL", "Firstrade", 75_000, equities),
        ("BTC", "Coinbase", 25_000, nil),
      ]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    let history = viewModel.categoryValueHistory
    #expect(history.count == 2)
    #expect(history["Equities"] != nil)
    #expect(history["Uncategorized"] != nil)
    #expect(history["Equities"]?.first?.value == 75_000)
    #expect(history["Uncategorized"]?.first?.value == 25_000)
  }

  // MARK: - Percentage Scaling

  @Test("Dashboard percentage metrics require 100x scaling for formattedPercentage")
  func percentageMetricsRequireScaling() throws {
    let tc = createTestContext()

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 1_000, nil)]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 2, day: 1),
      assets: [("AAPL", "Firstrade", 2_000, nil)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    let pct = try #require(viewModel.valueChangePercentage)
    // Raw decimal is 1.0 (100% growth). Must scale before formatting.
    let formatted = (pct * 100).formattedPercentage()
    // The formatted string should contain "100", not "1" or "0"
    #expect(formatted.contains("100"))
  }

  @Test("categoryValueHistory tracks values across multiple snapshots")
  func categoryValueHistoryMultipleSnapshots() {
    let tc = createTestContext()

    let equities = Category(name: "Equities")
    tc.context.insert(equities)

    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 1, day: 1),
      assets: [("AAPL", "Firstrade", 100_000, equities)]
    )
    createSnapshot(
      in: tc.context,
      date: makeDate(year: 2025, month: 2, day: 1),
      assets: [("AAPL", "Firstrade", 120_000, equities)]
    )

    let viewModel = DashboardViewModel(modelContext: tc.context)
    viewModel.loadData()

    let equitySeries = viewModel.categoryValueHistory["Equities"]
    #expect(equitySeries?.count == 2)
    #expect(equitySeries?[0].value == 100_000)
    #expect(equitySeries?[1].value == 120_000)
  }
}
