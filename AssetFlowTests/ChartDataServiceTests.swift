//
//  ChartDataServiceTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/15.
//

import Foundation
import Testing

@testable import AssetFlow

@Suite("ChartDataService Tests")
@MainActor
struct ChartDataServiceTests {

  // MARK: - Test Helpers

  private func makeDate(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar.current.date(from: components)!
  }

  // MARK: - ChartTimeRange.startDate Tests

  @Test("ChartTimeRange.all returns nil startDate")
  func allStartDateReturnsNil() {
    let reference = makeDate(year: 2025, month: 6, day: 15)
    #expect(ChartTimeRange.all.startDate(from: reference) == nil)
  }

  @Test("ChartTimeRange.oneWeek returns date 7 days before reference")
  func oneWeekStartDate() {
    let reference = makeDate(year: 2025, month: 6, day: 15)
    let result = ChartTimeRange.oneWeek.startDate(from: reference)
    let expected = Calendar.current.date(byAdding: .day, value: -7, to: reference)
    #expect(result == expected)
  }

  @Test("ChartTimeRange.oneMonth returns date 1 month before reference")
  func oneMonthStartDate() {
    let reference = makeDate(year: 2025, month: 6, day: 15)
    let result = ChartTimeRange.oneMonth.startDate(from: reference)
    let expected = Calendar.current.date(byAdding: .month, value: -1, to: reference)
    #expect(result == expected)
  }

  @Test("ChartTimeRange.threeMonths returns date 3 months before reference")
  func threeMonthsStartDate() {
    let reference = makeDate(year: 2025, month: 6, day: 15)
    let result = ChartTimeRange.threeMonths.startDate(from: reference)
    let expected = Calendar.current.date(byAdding: .month, value: -3, to: reference)
    #expect(result == expected)
  }

  @Test("ChartTimeRange.sixMonths returns date 6 months before reference")
  func sixMonthsStartDate() {
    let reference = makeDate(year: 2025, month: 6, day: 15)
    let result = ChartTimeRange.sixMonths.startDate(from: reference)
    let expected = Calendar.current.date(byAdding: .month, value: -6, to: reference)
    #expect(result == expected)
  }

  @Test("ChartTimeRange.oneYear returns date 1 year before reference")
  func oneYearStartDate() {
    let reference = makeDate(year: 2025, month: 6, day: 15)
    let result = ChartTimeRange.oneYear.startDate(from: reference)
    let expected = Calendar.current.date(byAdding: .year, value: -1, to: reference)
    #expect(result == expected)
  }

  @Test("ChartTimeRange.threeYears returns date 3 years before reference")
  func threeYearsStartDate() {
    let reference = makeDate(year: 2025, month: 6, day: 15)
    let result = ChartTimeRange.threeYears.startDate(from: reference)
    let expected = Calendar.current.date(byAdding: .year, value: -3, to: reference)
    #expect(result == expected)
  }

  @Test("ChartTimeRange.fiveYears returns date 5 years before reference")
  func fiveYearsStartDate() {
    let reference = makeDate(year: 2025, month: 6, day: 15)
    let result = ChartTimeRange.fiveYears.startDate(from: reference)
    let expected = Calendar.current.date(byAdding: .year, value: -5, to: reference)
    #expect(result == expected)
  }

  // MARK: - Filter Tests (DashboardDataPoint)

  @Test("Filter with .all returns all points")
  func filterAllReturnsAllPoints() {
    let points = [
      DashboardDataPoint(date: makeDate(year: 2020, month: 1, day: 1), value: 100),
      DashboardDataPoint(date: makeDate(year: 2023, month: 6, day: 1), value: 200),
      DashboardDataPoint(date: makeDate(year: 2025, month: 6, day: 15), value: 300),
    ]
    let result = ChartDataService.filter(points, range: .all)
    #expect(result.count == 3)
  }

  @Test("Filter with .oneMonth excludes points older than 1 month from latest")
  func filterOneMonthExcludesOldPoints() {
    let points = [
      DashboardDataPoint(date: makeDate(year: 2025, month: 1, day: 1), value: 100),
      DashboardDataPoint(date: makeDate(year: 2025, month: 5, day: 20), value: 200),
      DashboardDataPoint(date: makeDate(year: 2025, month: 6, day: 15), value: 300),
    ]
    let result = ChartDataService.filter(points, range: .oneMonth)
    #expect(result.count == 2)
    #expect(result[0].value == 200)
    #expect(result[1].value == 300)
  }

  @Test("Filter with .oneYear filters within 1 year range")
  func filterOneYearWithinRange() {
    let points = [
      DashboardDataPoint(date: makeDate(year: 2023, month: 1, day: 1), value: 50),
      DashboardDataPoint(date: makeDate(year: 2024, month: 8, day: 1), value: 100),
      DashboardDataPoint(date: makeDate(year: 2025, month: 3, day: 1), value: 200),
      DashboardDataPoint(date: makeDate(year: 2025, month: 6, day: 15), value: 300),
    ]
    let result = ChartDataService.filter(points, range: .oneYear)
    // 1Y from June 15 2025 = June 15 2024. Points Aug 2024 and later should be included.
    #expect(result.count == 3)
    #expect(result[0].value == 100)
  }

  @Test("Filter returns empty for empty input")
  func filterEmptyInput() {
    let result = ChartDataService.filter(
      [DashboardDataPoint](), range: .oneMonth)
    #expect(result.isEmpty)
  }

  @Test("Point exactly at range boundary is included")
  func filterBoundaryInclusion() {
    let reference = makeDate(year: 2025, month: 6, day: 15)
    let boundary = Calendar.current.date(byAdding: .month, value: -1, to: reference)!
    let points = [
      DashboardDataPoint(date: boundary, value: 100),
      DashboardDataPoint(date: reference, value: 200),
    ]
    let result = ChartDataService.filter(points, range: .oneMonth)
    #expect(result.count == 2)
  }

  @Test("Single data point with .oneWeek includes it")
  func filterSinglePointIncluded() {
    let points = [
      DashboardDataPoint(date: makeDate(year: 2025, month: 6, day: 15), value: 100)
    ]
    let result = ChartDataService.filter(points, range: .oneWeek)
    #expect(result.count == 1)
  }

  @Test("Stateless: filtering with .oneMonth then .all returns everything")
  func filterStatelessBehavior() {
    let points = [
      DashboardDataPoint(date: makeDate(year: 2020, month: 1, day: 1), value: 100),
      DashboardDataPoint(date: makeDate(year: 2025, month: 6, day: 15), value: 300),
    ]
    // First filter with .oneMonth (would exclude 2020 point)
    let filtered = ChartDataService.filter(points, range: .oneMonth)
    #expect(filtered.count == 1)

    // Then filter original data with .all — should return all
    let allFiltered = ChartDataService.filter(points, range: .all)
    #expect(allFiltered.count == 2)
  }

  // MARK: - Abbreviated Label Tests

  @Test("abbreviatedLabel for 5000 returns 5K")
  func abbreviatedLabel5K() {
    #expect(ChartDataService.abbreviatedLabel(for: 5_000) == "5K")
  }

  @Test("abbreviatedLabel for 1500 returns 1.5K")
  func abbreviatedLabel1Point5K() {
    #expect(ChartDataService.abbreviatedLabel(for: 1_500) == "1.5K")
  }

  @Test("abbreviatedLabel for 2000000 returns 2M")
  func abbreviatedLabel2M() {
    #expect(ChartDataService.abbreviatedLabel(for: 2_000_000) == "2M")
  }

  @Test("abbreviatedLabel for 3000000000 returns 3B")
  func abbreviatedLabel3B() {
    #expect(ChartDataService.abbreviatedLabel(for: 3_000_000_000) == "3B")
  }

  @Test("abbreviatedLabel for 500 returns 500 with no abbreviation")
  func abbreviatedLabelNoAbbreviation() {
    #expect(ChartDataService.abbreviatedLabel(for: 500) == "500")
  }

  @Test("abbreviatedLabel for 999999 rounds consistently to 1M")
  func abbreviatedLabel999999() {
    // 999,999 / 1,000 = 999.999 — String(format: "%.1f") rounds to "1000.0"
    // Should produce "1000K" (consistent rounding), not "999K" (truncation mismatch)
    #expect(ChartDataService.abbreviatedLabel(for: 999_999) == "1000K")
  }

  @Test("abbreviatedLabel for -5000 returns -5K")
  func abbreviatedLabelNegative5K() {
    #expect(ChartDataService.abbreviatedLabel(for: -5_000) == "-5K")
  }

  @Test("abbreviatedLabel for -2500000 returns -2.5M")
  func abbreviatedLabelNegative2Point5M() {
    #expect(ChartDataService.abbreviatedLabel(for: -2_500_000) == "-2.5M")
  }

  // MARK: - Rebase TWR Tests

  @Test("rebasedTWR with empty array returns empty")
  func rebasedTWREmpty() {
    let result = ChartDataService.rebasedTWR([])
    #expect(result.isEmpty)
  }

  @Test("rebasedTWR with single point returns point with value 0")
  func rebasedTWRSinglePoint() {
    let points = [
      DashboardDataPoint(
        date: makeDate(year: 2025, month: 6, day: 1), value: Decimal(string: "0.15")!)
    ]
    let result = ChartDataService.rebasedTWR(points)
    #expect(result.count == 1)
    #expect(result[0].value == 0)
  }

  @Test("rebasedTWR sets first point to 0% and rebases subsequent points")
  func rebasedTWRRebasesCorrectly() {
    // Inception TWR: 0% → 10% → 21% (two 10% periods chained)
    let points = [
      DashboardDataPoint(
        date: makeDate(year: 2025, month: 1, day: 1), value: Decimal(string: "0.0")!),
      DashboardDataPoint(
        date: makeDate(year: 2025, month: 2, day: 1), value: Decimal(string: "0.1")!),
      DashboardDataPoint(
        date: makeDate(year: 2025, month: 3, day: 1), value: Decimal(string: "0.21")!),
    ]
    let result = ChartDataService.rebasedTWR(points)
    #expect(result.count == 3)
    #expect(result[0].value == 0)  // first point = 0%
    #expect(result[1].value == Decimal(string: "0.1")!)  // (1.1/1.0)-1 = 0.1
    #expect(result[2].value == Decimal(string: "0.21")!)  // (1.21/1.0)-1 = 0.21
  }

  @Test("rebasedTWR with non-zero base rebases correctly")
  func rebasedTWRNonZeroBase() {
    // Simulates filtering a mid-range: inception TWR was 50% at start of range, 65% at end
    let points = [
      DashboardDataPoint(
        date: makeDate(year: 2025, month: 4, day: 1), value: Decimal(string: "0.5")!),
      DashboardDataPoint(
        date: makeDate(year: 2025, month: 5, day: 1), value: Decimal(string: "0.65")!),
    ]
    let result = ChartDataService.rebasedTWR(points)
    #expect(result[0].value == 0)
    // (1.65 / 1.5) - 1 = 0.1  (10% return in this sub-period)
    #expect(result[1].value == Decimal(1.65) / Decimal(1.5) - 1)
  }

  @Test("rebasedTWR with negative inception TWR rebases correctly")
  func rebasedTWRNegativeBase() {
    // Portfolio was down 20% at start of range, down 10% at end
    let points = [
      DashboardDataPoint(
        date: makeDate(year: 2025, month: 4, day: 1), value: Decimal(string: "-0.2")!),
      DashboardDataPoint(
        date: makeDate(year: 2025, month: 5, day: 1), value: Decimal(string: "-0.1")!),
    ]
    let result = ChartDataService.rebasedTWR(points)
    #expect(result[0].value == 0)
    // (0.9 / 0.8) - 1 = 0.125  (12.5% recovery)
    #expect(result[1].value == Decimal(0.9) / Decimal(0.8) - 1)
  }

  @Test("rebasedTWR preserves dates")
  func rebasedTWRPreservesDates() {
    let d1 = makeDate(year: 2025, month: 1, day: 1)
    let d2 = makeDate(year: 2025, month: 2, day: 1)
    let points = [
      DashboardDataPoint(date: d1, value: Decimal(string: "0.5")!),
      DashboardDataPoint(date: d2, value: Decimal(string: "0.65")!),
    ]
    let result = ChartDataService.rebasedTWR(points)
    #expect(result[0].date == d1)
    #expect(result[1].date == d2)
  }

  // MARK: - Filter Tests (CategoryValueHistoryEntry)

  @Test("Filter CategoryValueHistoryEntry with .threeMonths")
  func filterCategoryValueHistory() {
    let entries = [
      CategoryValueHistoryEntry(date: makeDate(year: 2025, month: 1, day: 1), totalValue: 100),
      CategoryValueHistoryEntry(date: makeDate(year: 2025, month: 5, day: 1), totalValue: 200),
      CategoryValueHistoryEntry(date: makeDate(year: 2025, month: 6, day: 15), totalValue: 300),
    ]
    let result = ChartDataService.filter(entries, range: .threeMonths)
    // 3M from June 15 = March 15. May 1 and June 15 are within range.
    #expect(result.count == 2)
    #expect(result[0].totalValue == 200)
  }

  // MARK: - Filter Tests (CategoryAllocationHistoryEntry)

  @Test("Filter CategoryAllocationHistoryEntry with .sixMonths")
  func filterCategoryAllocationHistory() {
    let entries = [
      CategoryAllocationHistoryEntry(
        date: makeDate(year: 2024, month: 6, day: 1), allocationPercentage: 40),
      CategoryAllocationHistoryEntry(
        date: makeDate(year: 2025, month: 3, day: 1), allocationPercentage: 50),
      CategoryAllocationHistoryEntry(
        date: makeDate(year: 2025, month: 6, day: 15), allocationPercentage: 60),
    ]
    let result = ChartDataService.filter(entries, range: .sixMonths)
    // 6M from June 15 2025 = Dec 15 2024. March and June are within range.
    #expect(result.count == 2)
    #expect(result[0].allocationPercentage == 50)
  }
}
