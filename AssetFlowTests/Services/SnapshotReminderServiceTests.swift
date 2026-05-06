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
import UserNotifications

@testable import AssetFlow

@Suite("SnapshotReminderService Tests")
@MainActor
struct SnapshotReminderServiceTests {

  // MARK: - Helpers

  private static var gregorian: Calendar {
    // UTC keeps the bi-weekly test free of DST surprises (where consecutive
    // 14-day strides drift by ±1h around DST transitions).
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = TimeZone(identifier: "UTC")!
    return cal
  }

  private static var referenceDate: Date {
    // Monday, 2026-01-05 08:00 UTC
    var components = DateComponents()
    components.year = 2026
    components.month = 1
    components.day = 5
    components.hour = 8
    components.minute = 0
    components.timeZone = TimeZone(identifier: "UTC")
    return Self.gregorian.date(from: components)!
  }

  private static var sampleContent: UNNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = "AssetFlow Reminder"
    content.body = "Time to add a new portfolio snapshot."
    content.categoryIdentifier = SnapshotReminderService.categoryIdentifier
    return content
  }

  // MARK: - makeRequests: Daily

  @Test("Daily config produces one repeating calendar trigger with hour and minute set")
  func makeRequestsDaily() throws {
    let config = SnapshotReminderConfig(
      frequency: .daily,
      weekday: 1, dayOfMonth: 1, hour: 9, minute: 30, intervalDays: 10)
    let requests = SnapshotReminderService.makeRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    #expect(requests.count == 1)
    let request = try #require(requests.first)
    #expect(request.identifier.hasPrefix(SnapshotReminderService.identifierPrefix))
    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.repeats == true)
    #expect(trigger.dateComponents.hour == 9)
    #expect(trigger.dateComponents.minute == 30)
    #expect(trigger.dateComponents.weekday == nil)
    #expect(trigger.dateComponents.day == nil)
  }

  // MARK: - makeRequests: Weekly

  @Test("Weekly config produces one repeating calendar trigger with weekday set")
  func makeRequestsWeekly() throws {
    let config = SnapshotReminderConfig(
      frequency: .weekly,
      weekday: 4, dayOfMonth: 1, hour: 18, minute: 15, intervalDays: 10)
    let requests = SnapshotReminderService.makeRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    #expect(requests.count == 1)
    let request = try #require(requests.first)
    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.repeats == true)
    #expect(trigger.dateComponents.hour == 18)
    #expect(trigger.dateComponents.minute == 15)
    #expect(trigger.dateComponents.weekday == 4)
    #expect(trigger.dateComponents.day == nil)
  }

  // MARK: - makeRequests: Monthly

  @Test("Monthly config produces one repeating calendar trigger with day set")
  func makeRequestsMonthly() throws {
    let config = SnapshotReminderConfig(
      frequency: .monthly,
      weekday: 1, dayOfMonth: 15, hour: 7, minute: 0, intervalDays: 10)
    let requests = SnapshotReminderService.makeRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    #expect(requests.count == 1)
    let request = try #require(requests.first)
    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.repeats == true)
    #expect(trigger.dateComponents.hour == 7)
    #expect(trigger.dateComponents.minute == 0)
    #expect(trigger.dateComponents.day == 15)
    #expect(trigger.dateComponents.weekday == nil)
  }

  // MARK: - makeRequests: Bi-weekly

  @Test("Bi-weekly config produces eight non-repeating triggers, 14 days apart")
  func makeRequestsBiweekly() throws {
    let config = SnapshotReminderConfig(
      frequency: .biweekly,
      weekday: 2, dayOfMonth: 1, hour: 10, minute: 0, intervalDays: 10)
    let requests = SnapshotReminderService.makeRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    #expect(requests.count == 8)
    for request in requests {
      #expect(request.identifier.hasPrefix(SnapshotReminderService.identifierPrefix))
      let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
      #expect(trigger.repeats == false)
      #expect(trigger.dateComponents.hour == 10)
      #expect(trigger.dateComponents.minute == 0)
    }

    // Consecutive firings should be exactly 14 days apart. Reconstruct
    // the firing dates from the trigger components (independent of system
    // wall-clock, unlike `nextTriggerDate()` which is nil for past dates).
    let firingDates: [Date] = requests.compactMap { request in
      guard
        let trigger = request.trigger as? UNCalendarNotificationTrigger
      else { return nil }
      return Self.gregorian.date(from: trigger.dateComponents)
    }
    #expect(firingDates.count == 8)
    for index in firingDates.indices.dropFirst() {
      let gap = firingDates[index].timeIntervalSince(firingDates[index - 1])
      #expect(abs(gap - 14 * 86_400) < 3_600)  // within 1h tolerance for DST
    }
  }

  @Test("Bi-weekly identifiers are all unique")
  func biweeklyIdentifiersUnique() {
    let config = SnapshotReminderConfig(
      frequency: .biweekly,
      weekday: 2, dayOfMonth: 1, hour: 10, minute: 0, intervalDays: 10)
    let requests = SnapshotReminderService.makeRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)
    let identifiers = Set(requests.map(\.identifier))
    #expect(identifiers.count == requests.count)
  }

  // MARK: - makeRequests: Custom interval

  @Test("Interval config produces eight non-repeating triggers, intervalDays apart")
  func makeRequestsInterval() throws {
    let config = SnapshotReminderConfig(
      frequency: .interval,
      weekday: 1, dayOfMonth: 1, hour: 8, minute: 0, intervalDays: 10)
    let requests = SnapshotReminderService.makeRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    #expect(requests.count == 8)
    for request in requests {
      #expect(request.identifier.hasPrefix("\(SnapshotReminderService.identifierPrefix)interval."))
      let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
      #expect(trigger.repeats == false)
      #expect(trigger.dateComponents.hour == 8)
      #expect(trigger.dateComponents.minute == 0)
    }

    let firingDates: [Date] = requests.compactMap { request in
      guard
        let trigger = request.trigger as? UNCalendarNotificationTrigger
      else { return nil }
      return Self.gregorian.date(from: trigger.dateComponents)
    }
    #expect(firingDates.count == 8)
    for index in firingDates.indices.dropFirst() {
      let gap = firingDates[index].timeIntervalSince(firingDates[index - 1])
      #expect(abs(gap - 10 * 86_400) < 3_600)
    }
  }

  @Test("Interval identifiers are all unique")
  func intervalIdentifiersUnique() {
    let config = SnapshotReminderConfig(
      frequency: .interval,
      weekday: 1, dayOfMonth: 1, hour: 8, minute: 0, intervalDays: 7)
    let requests = SnapshotReminderService.makeRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)
    let identifiers = Set(requests.map(\.identifier))
    #expect(identifiers.count == requests.count)
  }

  // MARK: - Content propagation

  @Test("Content title, body, and category propagate into every request")
  func makeRequestsPreservesContent() throws {
    let config = SnapshotReminderConfig.default
    let requests = SnapshotReminderService.makeRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    let request = try #require(requests.first)
    #expect(request.content.title == "AssetFlow Reminder")
    #expect(request.content.body == "Time to add a new portfolio snapshot.")
    #expect(request.content.categoryIdentifier == SnapshotReminderService.categoryIdentifier)
  }

  // MARK: - registerCategories

  @Test("registerCategories registers exactly one category with a snooze action")
  func registerCategoriesInstallsSnooze() {
    let center = FakeNotificationCenter()
    let service = SnapshotReminderService.createForTesting(center: center)

    service.registerCategories()

    #expect(center.setCategoriesCallCount == 1)
    #expect(center.lastCategories?.count == 1)
    let category = center.lastCategories?.first
    #expect(category?.identifier == SnapshotReminderService.categoryIdentifier)
    let actionIDs = (category?.actions ?? []).map(\.identifier)
    #expect(actionIDs.contains(SnapshotReminderService.snoozeActionIdentifier))
  }

  // MARK: - authorizationStatus

  @Test("authorizationStatus returns the underlying center's status")
  func authorizationStatusForwarded() async {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .authorized
    let service = SnapshotReminderService.createForTesting(center: center)

    let status = await service.authorizationStatus()

    #expect(status == .authorized)
  }

  // MARK: - reschedule

  @Test("reschedule removes only snapshotReminder-prefixed pending requests")
  func rescheduleRemovesOnlyPrefixed() async {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .authorized
    center.pending = [
      Self.makePending(identifier: "snapshotReminder.daily"),
      Self.makePending(identifier: "snapshotReminder.weekly"),
      Self.makePending(identifier: "exchangeRateRefresh"),
    ]
    let service = SnapshotReminderService.createForTesting(center: center)

    await service.reschedule(
      config: SnapshotReminderConfig(
        frequency: .weekly,
        weekday: 1, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10))

    let removedFlat = Set(center.removedIdentifiers.flatMap { $0 })
    #expect(removedFlat.contains("snapshotReminder.daily"))
    #expect(removedFlat.contains("snapshotReminder.weekly"))
    #expect(!removedFlat.contains("exchangeRateRefresh"))
  }

  @Test("reschedule with a weekly config adds one new request")
  func rescheduleWeeklyAdds() async {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .authorized
    let service = SnapshotReminderService.createForTesting(center: center)

    await service.reschedule(
      config: SnapshotReminderConfig(
        frequency: .weekly,
        weekday: 3, dayOfMonth: 1, hour: 11, minute: 0, intervalDays: 10))

    #expect(center.addedRequests.count == 1)
    let added = center.addedRequests.first
    #expect(added?.identifier == "\(SnapshotReminderService.identifierPrefix)weekly")
  }

  @Test("reschedule with nil config removes existing requests and adds none")
  func rescheduleNilCancels() async {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .authorized
    center.pending = [
      Self.makePending(identifier: "snapshotReminder.daily"),
      Self.makePending(identifier: "snapshotReminder.biweekly.0"),
    ]
    let service = SnapshotReminderService.createForTesting(center: center)

    await service.reschedule(config: nil)

    let removedFlat = Set(center.removedIdentifiers.flatMap { $0 })
    #expect(removedFlat.contains("snapshotReminder.daily"))
    #expect(removedFlat.contains("snapshotReminder.biweekly.0"))
    #expect(center.addedRequests.isEmpty)
  }

  @Test("reschedule is a no-op on add when authorization is denied")
  func rescheduleSkippedWhenDenied() async {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .denied
    let service = SnapshotReminderService.createForTesting(center: center)

    await service.reschedule(config: SnapshotReminderConfig.default)

    #expect(center.addedRequests.isEmpty)
  }

  @Test("reschedule(config:) preserves a pending one-shot snooze")
  func rescheduleKeepsSnooze() async {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .authorized
    let snoozeID = "\(SnapshotReminderService.snoozeIdentifierPrefix)abc-123"
    center.pending = [
      Self.makePending(identifier: "snapshotReminder.weekly"),
      Self.makePending(identifier: snoozeID),
    ]
    let service = SnapshotReminderService.createForTesting(center: center)

    await service.reschedule(
      config: SnapshotReminderConfig(
        frequency: .weekly,
        weekday: 2, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10))

    let removedFlat = Set(center.removedIdentifiers.flatMap { $0 })
    #expect(removedFlat.contains("snapshotReminder.weekly"))
    #expect(!removedFlat.contains(snoozeID))
  }

  @Test("reschedule(config: nil) also removes pending snoozes")
  func rescheduleNilRemovesSnooze() async {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .authorized
    let snoozeID = "\(SnapshotReminderService.snoozeIdentifierPrefix)xyz-789"
    center.pending = [
      Self.makePending(identifier: "snapshotReminder.daily"),
      Self.makePending(identifier: snoozeID),
    ]
    let service = SnapshotReminderService.createForTesting(center: center)

    await service.reschedule(config: nil)

    let removedFlat = Set(center.removedIdentifiers.flatMap { $0 })
    #expect(removedFlat.contains("snapshotReminder.daily"))
    #expect(removedFlat.contains(snoozeID))
  }

  // MARK: - snooze

  @Test("snooze adds exactly one one-shot time-interval trigger 24 hours out")
  func snoozeAdds24hOneShot() async throws {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .authorized
    let service = SnapshotReminderService.createForTesting(center: center)

    await service.snooze()

    #expect(center.addedRequests.count == 1)
    let request = try #require(center.addedRequests.first)
    let trigger = try #require(request.trigger as? UNTimeIntervalNotificationTrigger)
    #expect(trigger.repeats == false)
    #expect(trigger.timeInterval == 24 * 3_600)
    #expect(request.identifier.hasPrefix(SnapshotReminderService.snoozeIdentifierPrefix))
  }

  @Test("snooze does not touch existing recurring requests")
  func snoozePreservesExisting() async {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .authorized
    center.pending = [Self.makePending(identifier: "snapshotReminder.weekly")]
    let service = SnapshotReminderService.createForTesting(center: center)

    await service.snooze()

    #expect(center.removedIdentifiers.isEmpty)
  }

  // MARK: - topUpScheduleIfNeeded

  @Test("topUp adds the recurring trigger when missing for daily/weekly/monthly")
  func topUpAddsMissingRecurring() async {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .authorized
    let service = SnapshotReminderService.createForTesting(center: center)

    let config = SnapshotReminderConfig(
      frequency: .weekly,
      weekday: 2, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10)
    await service.topUpScheduleIfNeeded(config: config)

    #expect(center.addedRequests.count == 1)
    #expect(center.addedRequests.first?.identifier == "snapshotReminder.weekly")
  }

  @Test("topUp is a no-op when the recurring trigger is already pending")
  func topUpRecurringNoop() async {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .authorized
    center.pending = [Self.makePending(identifier: "snapshotReminder.weekly")]
    let service = SnapshotReminderService.createForTesting(center: center)

    let config = SnapshotReminderConfig(
      frequency: .weekly,
      weekday: 2, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10)
    await service.topUpScheduleIfNeeded(config: config)

    #expect(center.addedRequests.isEmpty)
    #expect(center.removedIdentifiers.isEmpty)
  }

  @Test("topUp is a no-op when 8 future bi-weekly slots are already pending")
  func topUpWindowedNoopWhenFull() async {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .authorized
    center.pending = Self.makeFutureBiweeklySlots(count: 8)
    let service = SnapshotReminderService.createForTesting(center: center)

    let config = SnapshotReminderConfig(
      frequency: .biweekly,
      weekday: 2, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10)
    await service.topUpScheduleIfNeeded(config: config)

    #expect(center.addedRequests.isEmpty)
    #expect(center.removedIdentifiers.isEmpty)
  }

  @Test("topUp tops the bi-weekly window up to 8 from a partial schedule")
  func topUpPartialWindow() async {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .authorized
    center.pending = Self.makeFutureBiweeklySlots(count: 3)
    let service = SnapshotReminderService.createForTesting(center: center)

    let config = SnapshotReminderConfig(
      frequency: .biweekly,
      weekday: 2, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10)
    await service.topUpScheduleIfNeeded(config: config)

    #expect(center.addedRequests.count == 5)
    #expect(center.removedIdentifiers.isEmpty)
  }

  @Test("topUp continues bi-weekly phase from the latest existing slot")
  func topUpPreservesPhase() async throws {
    let calendar = Self.gregorian
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .authorized
    // Single existing future slot 14 days out from a known anchor.
    let lastExistingComponents = DateComponents(
      timeZone: TimeZone(identifier: "UTC"),
      year: 2099, month: 1, day: 14, hour: 9, minute: 0)
    let trigger = UNCalendarNotificationTrigger(
      dateMatching: lastExistingComponents, repeats: false)
    let existing = UNNotificationRequest(
      identifier: "snapshotReminder.biweekly.existing",
      content: UNMutableNotificationContent(),
      trigger: trigger)
    center.pending = [existing]
    let service = SnapshotReminderService.createForTesting(center: center)

    let config = SnapshotReminderConfig(
      frequency: .biweekly,
      weekday: 2, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10)
    await service.topUpScheduleIfNeeded(config: config)

    #expect(center.addedRequests.count == 7)
    let firstNewTrigger = try #require(
      center.addedRequests.first?.trigger as? UNCalendarNotificationTrigger)
    let firstNewDate = try #require(
      calendar.date(from: firstNewTrigger.dateComponents))
    let lastExistingDate = try #require(calendar.date(from: lastExistingComponents))
    let gap = firstNewDate.timeIntervalSince(lastExistingDate)
    // The first newly-added slot should be exactly 14 days after the last
    // existing one (phase preserved). DST not applicable in UTC.
    #expect(abs(gap - 14 * 86_400) < 60)
  }

  @Test("topUp returns without scheduling when authorization is denied")
  func topUpSkippedWhenDenied() async {
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = .denied
    let service = SnapshotReminderService.createForTesting(center: center)

    let config = SnapshotReminderConfig(
      frequency: .weekly,
      weekday: 1, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10)
    await service.topUpScheduleIfNeeded(config: config)

    #expect(center.addedRequests.isEmpty)
  }

  // MARK: - Test helpers

  private static func makePending(identifier: String) -> UNNotificationRequest {
    let content = UNMutableNotificationContent()
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: 60, repeats: false)
    return UNNotificationRequest(
      identifier: identifier, content: content, trigger: trigger)
  }

  /// Builds `count` future-dated bi-weekly slots in UTC starting from a
  /// far-future anchor so they're guaranteed to be > now regardless of when
  /// the test runs.
  private static func makeFutureBiweeklySlots(count: Int) -> [UNNotificationRequest] {
    let calendar = Self.gregorian
    let anchor = DateComponents(
      timeZone: TimeZone(identifier: "UTC"),
      year: 2099, month: 1, day: 5, hour: 9, minute: 0)
    guard let anchorDate = calendar.date(from: anchor) else { return [] }
    return (0..<count).map { offset in
      let date =
        calendar.date(byAdding: .day, value: 14 * offset, to: anchorDate)
        ?? anchorDate
      let components = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute], from: date)
      let trigger = UNCalendarNotificationTrigger(
        dateMatching: components, repeats: false)
      return UNNotificationRequest(
        identifier: "snapshotReminder.biweekly.existing-\(offset)",
        content: UNMutableNotificationContent(),
        trigger: trigger)
    }
  }
}

// MARK: - Fake center

@MainActor
final class FakeNotificationCenter: UNUserNotificationCenterProtocol {
  var stubbedAuthorizationStatus: UNAuthorizationStatus = .notDetermined
  var stubbedRequestAuthorizationResult: Bool = true

  var setCategoriesCallCount = 0
  var lastCategories: Set<UNNotificationCategory>?

  var pending: [UNNotificationRequest] = []
  var addedRequests: [UNNotificationRequest] = []
  var removedIdentifiers: [[String]] = []
  var requestAuthorizationCallCount = 0

  func authorizationStatus() async -> UNAuthorizationStatus {
    stubbedAuthorizationStatus
  }

  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
    requestAuthorizationCallCount += 1
    // Mimic the OS: after the user responds to the prompt, the canonical
    // status moves out of `.notDetermined`.
    if stubbedAuthorizationStatus == .notDetermined {
      stubbedAuthorizationStatus =
        stubbedRequestAuthorizationResult
        ? .authorized : .denied
    }
    return stubbedRequestAuthorizationResult
  }

  func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {
    setCategoriesCallCount += 1
    lastCategories = categories
  }

  func add(_ request: UNNotificationRequest) async throws {
    addedRequests.append(request)
    pending.append(request)
  }

  func pendingNotificationRequests() async -> [UNNotificationRequest] {
    pending
  }

  func removePendingNotificationRequests(withIdentifiers identifiers: [String]) {
    removedIdentifiers.append(identifiers)
    pending.removeAll { identifiers.contains($0.identifier) }
  }

  func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?) {
    // no-op for tests
  }
}
