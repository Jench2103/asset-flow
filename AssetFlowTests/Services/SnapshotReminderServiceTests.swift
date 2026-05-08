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
    // UTC keeps bi-weekly tests free of DST surprises (where consecutive
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

  /// Builds a harness with a fresh `SettingsService`, fake center, and
  /// service. Tests mutate `harness.center.stubbedAuthorizationStatus`
  /// before exercising the manager, then assert the reconcile invariant via
  /// ``Self.assertInvariant(_:)``.
  @MainActor
  private struct Harness {
    let center: FakeNotificationCenter
    let settings: SettingsService
    let service: SnapshotReminderService
  }

  private static func makeHarness(
    enabled: Bool = false,
    config: SnapshotReminderConfig = .default,
    authorization: UNAuthorizationStatus = .authorized,
    architectureVersion: Int = SnapshotReminderService.currentArchitectureVersion,
    activeSnoozes: [Date] = [],
    hasNotificationsBeenAuthorized: Bool = false
  ) -> Harness {
    let settings = SettingsService.createForTesting()
    settings.snapshotReminderEnabled = enabled
    settings.snapshotReminderConfig = config
    settings.notificationsArchitectureVersion = architectureVersion
    settings.activeSnoozes = activeSnoozes
    settings.hasNotificationsBeenAuthorized = hasNotificationsBeenAuthorized
    let center = FakeNotificationCenter()
    center.stubbedAuthorizationStatus = authorization
    let service = SnapshotReminderService.createForTesting(
      center: center, settings: settings)
    return Harness(center: center, settings: settings, service: service)
  }

  /// The reconcile invariant — after every mutator, this must hold:
  ///
  /// pending requests in our namespace =
  ///   makeRecurringRequests(for: settings.config) when enabled+authorized
  ///   ∪ one snooze per future Date in settings.activeSnoozes
  ///   (else empty)
  ///
  /// Counts only — identifiers contain UUIDs we don't compare exactly.
  private static func assertInvariant(
    _ harness: Harness,
    sourceLocation: SourceLocation = #_sourceLocation
  ) {
    let recurring = harness.center.pending.filter {
      $0.identifier.hasPrefix(SnapshotReminderService.identifierPrefix)
        && !$0.identifier.hasPrefix(
          SnapshotReminderService.snoozeIdentifierPrefix)
    }
    let snoozes = harness.center.pending.filter {
      $0.identifier.hasPrefix(SnapshotReminderService.snoozeIdentifierPrefix)
    }

    let isEffectivelyEnabled =
      harness.settings.snapshotReminderEnabled
      && (harness.center.stubbedAuthorizationStatus == .authorized
        || harness.center.stubbedAuthorizationStatus == .provisional)

    if !isEffectivelyEnabled {
      #expect(recurring.isEmpty, sourceLocation: sourceLocation)
      #expect(snoozes.isEmpty, sourceLocation: sourceLocation)
      return
    }

    let expectedRecurringCount = SnapshotReminderService.makeRecurringRequests(
      for: harness.settings.snapshotReminderConfig,
      content: UNMutableNotificationContent(),
      from: Date(),
      calendar: .current
    ).count
    let now = Date()
    let expectedSnoozeCount =
      harness.settings.activeSnoozes.filter { $0 > now }.count

    #expect(recurring.count == expectedRecurringCount, sourceLocation: sourceLocation)
    #expect(snoozes.count == expectedSnoozeCount, sourceLocation: sourceLocation)
  }

  // MARK: - makeRecurringRequests: Daily

  @Test("Daily config produces one repeating calendar trigger with hour and minute set")
  func dailyProducesRepeatingTrigger() throws {
    let config = SnapshotReminderConfig(
      frequency: .daily,
      weekday: 1, dayOfMonth: 1, hour: 8, minute: 30, intervalDays: 10)

    let requests = SnapshotReminderService.makeRecurringRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    #expect(requests.count == 1)
    let request = try #require(requests.first)
    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.repeats == true)
    #expect(trigger.dateComponents.hour == 8)
    #expect(trigger.dateComponents.minute == 30)
    #expect(trigger.dateComponents.weekday == nil)
    #expect(trigger.dateComponents.day == nil)
  }

  // MARK: - makeRecurringRequests: Weekly

  @Test("Weekly config produces one repeating calendar trigger with weekday set")
  func weeklyProducesRepeatingTriggerWithWeekday() throws {
    let config = SnapshotReminderConfig(
      frequency: .weekly,
      weekday: 4, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10)

    let requests = SnapshotReminderService.makeRecurringRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    #expect(requests.count == 1)
    let request = try #require(requests.first)
    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.repeats == true)
    #expect(trigger.dateComponents.weekday == 4)
    #expect(trigger.dateComponents.hour == 9)
    #expect(trigger.dateComponents.minute == 0)
  }

  // MARK: - makeRecurringRequests: Monthly

  @Test("Monthly config produces one repeating calendar trigger with day set")
  func monthlyProducesRepeatingTriggerWithDay() throws {
    let config = SnapshotReminderConfig(
      frequency: .monthly,
      weekday: 1, dayOfMonth: 15, hour: 18, minute: 45, intervalDays: 10)

    let requests = SnapshotReminderService.makeRecurringRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    #expect(requests.count == 1)
    let request = try #require(requests.first)
    let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
    #expect(trigger.repeats == true)
    #expect(trigger.dateComponents.day == 15)
    #expect(trigger.dateComponents.hour == 18)
    #expect(trigger.dateComponents.minute == 45)
  }

  // MARK: - makeRecurringRequests: Bi-weekly

  @Test("Bi-weekly config produces eight non-repeating triggers, 14 days apart")
  func biweeklyProducesEightWindowedTriggers() throws {
    let config = SnapshotReminderConfig(
      frequency: .biweekly,
      weekday: 2, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10)

    let requests = SnapshotReminderService.makeRecurringRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    #expect(requests.count == 8)

    // Each trigger is non-repeating
    for request in requests {
      let trigger = try #require(request.trigger as? UNCalendarNotificationTrigger)
      #expect(trigger.repeats == false)
    }

    // Slots are 14 days apart
    let dates = requests.compactMap {
      ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents
    }.compactMap(Self.gregorian.date(from:))
    #expect(dates.count == 8)
    let sorted = dates.sorted()
    for index in 1..<sorted.count {
      let interval = sorted[index].timeIntervalSince(sorted[index - 1])
      #expect(abs(interval - 14 * 86_400) < 60)
    }
  }

  @Test("Bi-weekly identifiers are all unique")
  func biweeklyIdentifiersUnique() {
    let config = SnapshotReminderConfig(
      frequency: .biweekly,
      weekday: 2, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10)

    let requests = SnapshotReminderService.makeRecurringRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    let identifiers = Set(requests.map(\.identifier))
    #expect(identifiers.count == requests.count)
  }

  // MARK: - makeRecurringRequests: Interval

  @Test("Interval config produces eight non-repeating triggers, intervalDays apart")
  func intervalProducesEightWindowedTriggers() throws {
    let config = SnapshotReminderConfig(
      frequency: .interval,
      weekday: 1, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10)

    let requests = SnapshotReminderService.makeRecurringRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    #expect(requests.count == 8)

    let dates = requests.compactMap {
      ($0.trigger as? UNCalendarNotificationTrigger)?.dateComponents
    }.compactMap(Self.gregorian.date(from:))
    #expect(dates.count == 8)
    let sorted = dates.sorted()
    for index in 1..<sorted.count {
      let interval = sorted[index].timeIntervalSince(sorted[index - 1])
      #expect(abs(interval - 10 * 86_400) < 60)
    }
  }

  @Test("Interval identifiers are all unique")
  func intervalIdentifiersUnique() {
    let config = SnapshotReminderConfig(
      frequency: .interval,
      weekday: 1, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 7)

    let requests = SnapshotReminderService.makeRecurringRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    let identifiers = Set(requests.map(\.identifier))
    #expect(identifiers.count == requests.count)
  }

  // MARK: - Content propagation

  @Test("Content title, body, and category propagate into every request")
  func contentPropagates() throws {
    let config = SnapshotReminderConfig(
      frequency: .daily,
      weekday: 1, dayOfMonth: 1, hour: 9, minute: 0, intervalDays: 10)

    let requests = SnapshotReminderService.makeRecurringRequests(
      for: config, content: Self.sampleContent,
      from: Self.referenceDate, calendar: Self.gregorian)

    let request = try #require(requests.first)
    #expect(request.content.title == "AssetFlow Reminder")
    #expect(request.content.body == "Time to add a new portfolio snapshot.")
    #expect(request.content.categoryIdentifier == SnapshotReminderService.categoryIdentifier)
  }

  // MARK: - Categories + Authorization

  @Test("registerCategories registers exactly one category with a snooze action")
  func registerCategoriesInstallsSnooze() {
    let harness = Self.makeHarness()
    harness.service.registerCategories()

    #expect(harness.center.setCategoriesCallCount == 1)
    #expect(harness.center.lastCategories?.count == 1)
    let category = harness.center.lastCategories?.first
    #expect(category?.identifier == SnapshotReminderService.categoryIdentifier)
    let actionIDs = (category?.actions ?? []).map(\.identifier)
    #expect(actionIDs.contains(SnapshotReminderService.snoozeActionIdentifier))
  }

  @Test("authorizationStatus returns the underlying center's status")
  func authorizationStatusForwarded() async {
    let harness = Self.makeHarness(authorization: .authorized)
    let status = await harness.service.authorizationStatus()
    #expect(status == .authorized)
  }

  // MARK: - setEnabled — happy path

  @Test("setEnabled(true) when authorized: schedules and the invariant holds")
  func setEnabledTrue_whenAuthorized_schedules() async {
    let harness = Self.makeHarness(authorization: .authorized)

    let result = await harness.service.setEnabled(true)

    #expect(result == .authorized)
    #expect(harness.settings.snapshotReminderEnabled == true)
    #expect(harness.settings.hasNotificationsBeenAuthorized == true)
    Self.assertInvariant(harness)
  }

  @Test("setEnabled(true) when notDetermined: requests authorization")
  func setEnabledTrue_whenNotDetermined_requestsAuth() async {
    let harness = Self.makeHarness(authorization: .notDetermined)
    harness.center.stubbedRequestAuthorizationResult = true

    let result = await harness.service.setEnabled(true)

    #expect(harness.center.requestAuthorizationCallCount == 1)
    #expect(result == .authorized)
    #expect(harness.settings.snapshotReminderEnabled == true)
    Self.assertInvariant(harness)
  }

  @Test(
    """
    setEnabled(true) when denied without prior auth: reverts intent and \
    returns .registrationFailure
    """)
  func setEnabledTrue_deniedFirstTime_isRegistrationFailure() async {
    let harness = Self.makeHarness(authorization: .denied)

    let result = await harness.service.setEnabled(true)

    #expect(result == .registrationFailure)
    #expect(harness.settings.snapshotReminderEnabled == false)
    Self.assertInvariant(harness)
  }

  @Test(
    """
    setEnabled(true) when denied with prior auth: reverts intent and returns \
    .deniedInSystemSettings
    """)
  func setEnabledTrue_deniedAfterPriorAuth_isDeniedInSystemSettings() async {
    let harness = Self.makeHarness(
      authorization: .denied, hasNotificationsBeenAuthorized: true)

    let result = await harness.service.setEnabled(true)

    #expect(result == .deniedInSystemSettings)
    #expect(harness.settings.snapshotReminderEnabled == false)
    Self.assertInvariant(harness)
  }

  @Test("setEnabled(false) wipes pending and clears activeSnoozes")
  func setEnabledFalse_wipesAndClearsSnoozes() async {
    let harness = Self.makeHarness(
      enabled: true,
      authorization: .authorized,
      activeSnoozes: [Date().addingTimeInterval(3_600)])
    // Establish a baseline schedule first.
    _ = await harness.service.setEnabled(true)
    #expect(!harness.center.pending.isEmpty)

    let result = await harness.service.setEnabled(false)

    #expect(result == .authorized)  // disable always succeeds
    #expect(harness.settings.snapshotReminderEnabled == false)
    #expect(harness.settings.activeSnoozes.isEmpty)
    Self.assertInvariant(harness)
  }

  // MARK: - updateConfig

  @Test("updateConfig changes the cadence and the invariant holds")
  func updateConfig_switchesCadence() async {
    let harness = Self.makeHarness(authorization: .authorized)
    _ = await harness.service.setEnabled(true)
    Self.assertInvariant(harness)

    await harness.service.updateConfig { $0.frequency = .biweekly }

    #expect(harness.settings.snapshotReminderConfig.frequency == .biweekly)
    Self.assertInvariant(harness)
    // Bi-weekly produces 8 windowed slots
    let recurringCount = harness.center.pending.filter {
      $0.identifier.hasPrefix(SnapshotReminderService.identifierPrefix)
        && !$0.identifier.hasPrefix(
          SnapshotReminderService.snoozeIdentifierPrefix)
    }.count
    #expect(recurringCount == 8)
  }

  @Test("updateConfig with a no-op transform is idempotent and reconciles")
  func updateConfig_noop_isIdempotent() async {
    let harness = Self.makeHarness(authorization: .authorized)
    _ = await harness.service.setEnabled(true)
    let baseline = harness.center.pending.count

    await harness.service.updateConfig { _ in }

    #expect(harness.center.pending.count == baseline)
    Self.assertInvariant(harness)
  }

  // MARK: - recordSnooze

  @Test("recordSnooze appends to activeSnoozes and reconciles a snooze in pending")
  func recordSnooze_appearsInPending() async {
    let harness = Self.makeHarness(authorization: .authorized)
    _ = await harness.service.setEnabled(true)

    await harness.service.recordSnooze()

    #expect(harness.settings.activeSnoozes.count == 1)
    let snoozesInPending = harness.center.pending.filter {
      $0.identifier.hasPrefix(SnapshotReminderService.snoozeIdentifierPrefix)
    }
    #expect(snoozesInPending.count == 1)
    Self.assertInvariant(harness)
  }

  @Test(
    """
    Snooze survives an updateConfig (regression: snoozes used to depend on \
    being preserved by a filter predicate during reschedule; now they're \
    backed by `settings.activeSnoozes` and re-added by reconcile)
    """)
  func snooze_survivesConfigChange() async {
    let harness = Self.makeHarness(authorization: .authorized)
    _ = await harness.service.setEnabled(true)
    await harness.service.recordSnooze()
    let snoozesBefore = harness.center.pending.filter {
      $0.identifier.hasPrefix(SnapshotReminderService.snoozeIdentifierPrefix)
    }.count
    #expect(snoozesBefore == 1)

    await harness.service.updateConfig { $0.frequency = .monthly }

    let snoozesAfter = harness.center.pending.filter {
      $0.identifier.hasPrefix(SnapshotReminderService.snoozeIdentifierPrefix)
    }.count
    #expect(snoozesAfter == 1)
    #expect(harness.settings.activeSnoozes.count == 1)
    Self.assertInvariant(harness)
  }

  @Test("Snoozes are cleared when the user disables")
  func snooze_clearedOnDisable() async {
    let harness = Self.makeHarness(authorization: .authorized)
    _ = await harness.service.setEnabled(true)
    await harness.service.recordSnooze()
    #expect(harness.settings.activeSnoozes.count == 1)

    _ = await harness.service.setEnabled(false)

    #expect(harness.settings.activeSnoozes.isEmpty)
    let snoozesInPending = harness.center.pending.filter {
      $0.identifier.hasPrefix(SnapshotReminderService.snoozeIdentifierPrefix)
    }
    #expect(snoozesInPending.isEmpty)
    Self.assertInvariant(harness)
  }

  @Test("Multiple snoozes accumulate in pending (one per recordSnooze call)")
  func snooze_multipleAccumulate() async {
    let harness = Self.makeHarness(authorization: .authorized)
    _ = await harness.service.setEnabled(true)

    await harness.service.recordSnooze()
    await harness.service.recordSnooze()
    await harness.service.recordSnooze()

    #expect(harness.settings.activeSnoozes.count == 3)
    let snoozesInPending = harness.center.pending.filter {
      $0.identifier.hasPrefix(SnapshotReminderService.snoozeIdentifierPrefix)
    }
    #expect(snoozesInPending.count == 3)
    Self.assertInvariant(harness)
  }

  @Test("Expired snoozes are dropped on reconcile")
  func expiredSnoozes_droppedOnReconcile() async {
    let pastDate = Date().addingTimeInterval(-3_600)
    let futureDate = Date().addingTimeInterval(3_600)
    let harness = Self.makeHarness(
      enabled: true,
      authorization: .authorized,
      activeSnoozes: [pastDate, futureDate])

    await harness.service.reconcileOnLaunch()

    #expect(harness.settings.activeSnoozes.count == 1)
    #expect(harness.settings.activeSnoozes.first == futureDate)
    Self.assertInvariant(harness)
  }

  // MARK: - reconcileOnLaunch — migration

  @Test(
    """
    First-launch migration (architectureVersion 0 → 1) wipes the entire \
    namespace, including legacy identifiers the current code wouldn't \
    recognize, and clears any uncoupled activeSnoozes
    """)
  func migration_v0ToCurrent_wipesNamespaceAndSnoozes() async {
    let harness = Self.makeHarness(
      enabled: false, authorization: .authorized, architectureVersion: 0)
    let recurringTrigger = UNCalendarNotificationTrigger(
      dateMatching: DateComponents(hour: 9, minute: 0, weekday: 1),
      repeats: true)
    harness.center.pending = [
      UNNotificationRequest(
        identifier: "snapshotReminder.weekly",
        content: UNMutableNotificationContent(),
        trigger: recurringTrigger),
      UNNotificationRequest(
        identifier: "snapshotReminder.legacy.UUID-orphan",
        content: UNMutableNotificationContent(),
        trigger: recurringTrigger),
      UNNotificationRequest(
        identifier: "snapshotReminder.snooze.OLD",
        content: UNMutableNotificationContent(),
        trigger: recurringTrigger),
      // Out-of-namespace request must survive.
      UNNotificationRequest(
        identifier: "exchangeRateRefresh",
        content: UNMutableNotificationContent(),
        trigger: recurringTrigger),
    ]
    harness.settings.activeSnoozes = [Date().addingTimeInterval(3_600)]

    await harness.service.reconcileOnLaunch()

    let identifiers = Set(harness.center.pending.map(\.identifier))
    #expect(!identifiers.contains("snapshotReminder.weekly"))
    #expect(!identifiers.contains("snapshotReminder.legacy.UUID-orphan"))
    #expect(!identifiers.contains("snapshotReminder.snooze.OLD"))
    #expect(identifiers.contains("exchangeRateRefresh"))
    #expect(harness.settings.activeSnoozes.isEmpty)
    #expect(
      harness.settings.notificationsArchitectureVersion
        == SnapshotReminderService.currentArchitectureVersion)
    Self.assertInvariant(harness)
  }

  @Test("reconcileOnLaunch is a no-op (no migration) when version is current")
  func reconcileOnLaunch_noMigration_whenCurrentVersion() async {
    let harness = Self.makeHarness(
      enabled: true, authorization: .authorized,
      architectureVersion: SnapshotReminderService.currentArchitectureVersion)
    _ = await harness.service.setEnabled(true)
    let baselineCount = harness.center.pending.count

    await harness.service.reconcileOnLaunch()

    // Pending matches the post-reconcile invariant; no orphan migration ran.
    #expect(harness.center.pending.count == baselineCount)
    Self.assertInvariant(harness)
  }

  // MARK: - reconcileOnLaunch — drift recovery

  @Test(
    """
    reconcileOnLaunch heals drift between settings (disabled) and pending \
    (stale entries left over from a crash mid-disable)
    """)
  func reconcileOnLaunch_disabled_wipesDriftedPending() async {
    let harness = Self.makeHarness(
      enabled: false, authorization: .authorized)
    let recurringTrigger = UNCalendarNotificationTrigger(
      dateMatching: DateComponents(hour: 9, minute: 0, weekday: 1),
      repeats: true)
    harness.center.pending = [
      UNNotificationRequest(
        identifier: "snapshotReminder.weekly",
        content: UNMutableNotificationContent(),
        trigger: recurringTrigger)
    ]

    await harness.service.reconcileOnLaunch()

    let ours = harness.center.pending.filter {
      $0.identifier.hasPrefix(SnapshotReminderService.identifierPrefix)
    }
    #expect(ours.isEmpty)
    Self.assertInvariant(harness)
  }

  @Test(
    """
    reconcileOnLaunch enabled+authorized: rebuilds desired schedule even if \
    pending was empty (post-crash recovery, fresh install drift)
    """)
  func reconcileOnLaunch_enabled_rebuildsMissingSchedule() async {
    let harness = Self.makeHarness(enabled: true, authorization: .authorized)
    #expect(harness.center.pending.isEmpty)

    await harness.service.reconcileOnLaunch()

    let ours = harness.center.pending.filter {
      $0.identifier.hasPrefix(SnapshotReminderService.identifierPrefix)
        && !$0.identifier.hasPrefix(
          SnapshotReminderService.snoozeIdentifierPrefix)
    }
    #expect(!ours.isEmpty)
    Self.assertInvariant(harness)
  }

  // MARK: - Serialization

  @Test(
    """
    Rapid-fire mutations (enable → updateConfig → disable) end in the \
    correct final state with no leak — the serial reconcile queue makes \
    intermediate state unobservable to the system
    """)
  func serialQueue_finalStateIsLatestIntent() async {
    let harness = Self.makeHarness(authorization: .authorized)

    async let a: SnapshotReminderService.AuthorizationResult =
      harness.service.setEnabled(true)
    async let b: Void = harness.service.updateConfig { $0.frequency = .biweekly }
    async let c: SnapshotReminderService.AuthorizationResult =
      harness.service.setEnabled(false)

    _ = await (a, b, c)

    #expect(harness.settings.snapshotReminderEnabled == false)
    #expect(harness.settings.activeSnoozes.isEmpty)
    let ours = harness.center.pending.filter {
      $0.identifier.hasPrefix(SnapshotReminderService.identifierPrefix)
    }
    #expect(ours.isEmpty)
    Self.assertInvariant(harness)
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

  /// When `true`, `requestAuthorization` suspends on a continuation until
  /// the test calls ``resolveAuthorizationPrompt(grant:)``. Lets tests
  /// reproduce the macOS prompt's real timing.
  var suspendOnRequestAuthorization: Bool = false
  private(set) var requestAuthorizationContinuation: CheckedContinuation<Bool, Error>?

  func authorizationStatus() async -> UNAuthorizationStatus {
    stubbedAuthorizationStatus
  }

  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
    requestAuthorizationCallCount += 1
    if suspendOnRequestAuthorization {
      return try await withCheckedThrowingContinuation { continuation in
        self.requestAuthorizationContinuation = continuation
      }
    }
    if stubbedAuthorizationStatus == .notDetermined {
      stubbedAuthorizationStatus =
        stubbedRequestAuthorizationResult ? .authorized : .denied
    }
    return stubbedRequestAuthorizationResult
  }

  /// Resolves a pending suspended `requestAuthorization` call. Mirrors the
  /// macOS prompt: updates `stubbedAuthorizationStatus` based on the user's
  /// choice before resuming the continuation.
  func resolveAuthorizationPrompt(grant: Bool) {
    guard let continuation = requestAuthorizationContinuation else { return }
    requestAuthorizationContinuation = nil
    if stubbedAuthorizationStatus == .notDetermined {
      stubbedAuthorizationStatus = grant ? .authorized : .denied
    }
    continuation.resume(returning: grant)
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
