//  AssetFlow — snapshot-based portfolio management for macOS.
//  Copyright (C) 2026 Jen-Chien Chang
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//

import Foundation
import Testing

@testable import AssetFlow

@Suite("SnapshotTimeBucket Tests")
@MainActor
struct SnapshotTimeBucketTests {

  /// Reference date: 2026-02-17 (February 17, 2026)
  private let referenceDate: Date = {
    var components = DateComponents()
    components.year = 2026
    components.month = 2
    components.day = 17
    return Calendar.current.date(from: components)!
  }()

  private func date(year: Int, month: Int, day: Int) -> Date {
    var components = DateComponents()
    components.year = year
    components.month = month
    components.day = day
    return Calendar.current.date(from: components)!
  }

  // MARK: - Basic Bucket Assignment

  @Test("Date in current month returns thisMonth")
  func testCurrentMonth() {
    let result = SnapshotTimeBucket.bucket(
      for: date(year: 2026, month: 2, day: 10), relativeTo: referenceDate)
    #expect(result == .thisMonth)
  }

  @Test("Date 1 month ago returns past3Months")
  func testOneMonthAgo() {
    let result = SnapshotTimeBucket.bucket(
      for: date(year: 2026, month: 1, day: 15), relativeTo: referenceDate)
    #expect(result == .past3Months)
  }

  @Test("Date 3 months ago boundary returns past6Months")
  func testThreeMonthsAgoBoundary() {
    // 3 months before Feb 2026 start = Nov 2025 start
    // A date in Oct 2025 (before Nov start) is past6Months
    let result = SnapshotTimeBucket.bucket(
      for: date(year: 2025, month: 10, day: 31), relativeTo: referenceDate)
    #expect(result == .past6Months)
  }

  @Test("Date 6 months ago boundary returns pastYear")
  func testSixMonthsAgoBoundary() {
    // 6 months before Feb 2026 start = Aug 2025 start
    // A date in Jul 2025 (before Aug start) is pastYear
    let result = SnapshotTimeBucket.bucket(
      for: date(year: 2025, month: 7, day: 31), relativeTo: referenceDate)
    #expect(result == .pastYear)
  }

  @Test("Date 9 months ago returns pastYear")
  func testNineMonthsAgo() {
    let result = SnapshotTimeBucket.bucket(
      for: date(year: 2025, month: 5, day: 15), relativeTo: referenceDate)
    #expect(result == .pastYear)
  }

  @Test("Date more than 12 months ago returns older")
  func testMoreThanOneYearAgo() {
    let result = SnapshotTimeBucket.bucket(
      for: date(year: 2024, month: 12, day: 1), relativeTo: referenceDate)
    #expect(result == .older)
  }

  // MARK: - Boundary Tests

  @Test("First day of current month returns thisMonth")
  func testFirstDayOfCurrentMonth() {
    let result = SnapshotTimeBucket.bucket(
      for: date(year: 2026, month: 2, day: 1), relativeTo: referenceDate)
    #expect(result == .thisMonth)
  }

  @Test("Last day of previous month returns past3Months")
  func testLastDayOfPreviousMonth() {
    let result = SnapshotTimeBucket.bucket(
      for: date(year: 2026, month: 1, day: 31), relativeTo: referenceDate)
    #expect(result == .past3Months)
  }

  @Test("Exactly 3 months ago start of that month returns past3Months — inclusive boundary")
  func testExactlyThreeMonthsAgoInclusive() {
    // 3 months before Feb 2026 start = Nov 1, 2025
    let result = SnapshotTimeBucket.bucket(
      for: date(year: 2025, month: 11, day: 1), relativeTo: referenceDate)
    #expect(result == .past3Months)
  }

  @Test("One day before 3-month boundary returns past6Months")
  func testOneDayBeforeThreeMonthBoundary() {
    // 3 months before Feb 2026 start = Nov 1, 2025
    // One day before = Oct 31, 2025
    let result = SnapshotTimeBucket.bucket(
      for: date(year: 2025, month: 10, day: 31), relativeTo: referenceDate)
    #expect(result == .past6Months)
  }
}
