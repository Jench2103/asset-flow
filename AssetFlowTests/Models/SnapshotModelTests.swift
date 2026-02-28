//
//  SnapshotModelTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("Snapshot Model Tests")
@MainActor
struct SnapshotModelTests {

  // MARK: - Creation and Properties

  @Test("Snapshot initializes with date normalized to start of day")
  func testInitializesWithDateNormalizedToStartOfDay() {
    var components = DateComponents()
    components.year = 2025
    components.month = 6
    components.day = 15
    components.hour = 14
    components.minute = 30
    let date = Calendar.current.date(from: components)!

    let snapshot = Snapshot(date: date)
    let expected = Calendar.current.startOfDay(for: date)

    #expect(snapshot.date == expected)
  }

  @Test("Snapshot sets createdAt to current time")
  func testSetsCreatedAtToCurrentTime() {
    let before = Date()
    let snapshot = Snapshot(date: Date())
    let after = Date()

    #expect(snapshot.createdAt >= before)
    #expect(snapshot.createdAt <= after)
  }

  @Test("Snapshot persists in SwiftData context")
  func testPersistsInContext() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let date = Calendar.current.startOfDay(for: Date())
    let snapshot = Snapshot(date: date)
    context.insert(snapshot)

    let descriptor = FetchDescriptor<Snapshot>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.count == 1)
    #expect(fetched.first?.date == date)
  }

  // MARK: - Relationships

  @Test("Snapshot assetValues starts empty")
  func testAssetValuesStartsEmpty() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let snapshot = Snapshot(date: Date())
    context.insert(snapshot)

    #expect(snapshot.assetValues?.isEmpty ?? true)
  }

  @Test("Snapshot cashFlowOperations starts empty")
  func testCashFlowOperationsStartsEmpty() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let snapshot = Snapshot(date: Date())
    context.insert(snapshot)

    #expect(snapshot.cashFlowOperations?.isEmpty ?? true)
  }

  // MARK: - Date Normalization

  @Test("Different times on the same day normalize to same date")
  func testDifferentTimesNormalizeToSameDate() {
    var morning = DateComponents()
    morning.year = 2025
    morning.month = 3
    morning.day = 1
    morning.hour = 8
    let morningDate = Calendar.current.date(from: morning)!

    var evening = DateComponents()
    evening.year = 2025
    evening.month = 3
    evening.day = 1
    evening.hour = 22
    let eveningDate = Calendar.current.date(from: evening)!

    let snapshotA = Snapshot(date: morningDate)
    let snapshotB = Snapshot(date: eveningDate)

    #expect(snapshotA.date == snapshotB.date)
  }

  @Test("Different days normalize to different dates")
  func testDifferentDaysNormalizeToDifferentDates() {
    var day1 = DateComponents()
    day1.year = 2025
    day1.month = 3
    day1.day = 1
    let date1 = Calendar.current.date(from: day1)!

    var day2 = DateComponents()
    day2.year = 2025
    day2.month = 3
    day2.day = 2
    let date2 = Calendar.current.date(from: day2)!

    let snapshotA = Snapshot(date: date1)
    let snapshotB = Snapshot(date: date2)

    #expect(snapshotA.date != snapshotB.date)
  }

  // MARK: - Uniqueness

  @Test("Snapshot enforces date uniqueness via #Unique — duplicate date upserts")
  func testSnapshotEnforcesDateUniqueness() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let date = Calendar.current.startOfDay(
      for: Calendar.current.date(from: DateComponents(year: 2025, month: 1, day: 1))!)
    let snapshot1 = Snapshot(date: date)
    let snapshot2 = Snapshot(date: date)
    context.insert(snapshot1)
    context.insert(snapshot2)
    try context.save()

    let descriptor = FetchDescriptor<Snapshot>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.count == 1)
  }

  // MARK: - Multiple Snapshots

  @Test("Multiple snapshots can be stored in the same context")
  func testMultipleSnapshotsInSameContext() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    var components1 = DateComponents()
    components1.year = 2025
    components1.month = 1
    components1.day = 1
    let date1 = Calendar.current.date(from: components1)!

    var components2 = DateComponents()
    components2.year = 2025
    components2.month = 2
    components2.day = 1
    let date2 = Calendar.current.date(from: components2)!

    context.insert(Snapshot(date: date1))
    context.insert(Snapshot(date: date2))

    let descriptor = FetchDescriptor<Snapshot>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.count == 2)
  }
}
