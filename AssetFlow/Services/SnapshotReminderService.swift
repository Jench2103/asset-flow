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
import UserNotifications

/// Reconciliation manager for snapshot reminder notifications. Every
/// mutation routes through `reconcile()`, whose contract is: after it
/// returns, pending requests in the `snapshotReminder.*` namespace equal
/// `makeRecurringRequests(for: settings.snapshotReminderConfig)` plus one
/// snooze request per future `Date` in `settings.activeSnoozes`, or are
/// empty when disabled or unauthorized. See `Documentation/Architecture.md`.
@Observable
@MainActor
final class SnapshotReminderService: NSObject {
  static let shared: SnapshotReminderService = .init(
    center: UNUserNotificationCenter.current(),
    settings: SettingsService.shared)

  static let categoryIdentifier = "snapshotReminder"
  static let snoozeActionIdentifier = "snooze"
  static let identifierPrefix = "snapshotReminder."
  static let snoozeIdentifierPrefix = "snapshotReminder.snooze."

  /// Bumped when the on-disk identifier scheme or storage layout changes;
  /// gates the migration in `reconcileOnLaunch`.
  static let currentArchitectureVersion = 1

  private let center: any UNUserNotificationCenterProtocol
  private let settings: SettingsService

  /// Holds only the latest enqueued task; each new task awaits it before
  /// running, so reconciles never interleave.
  private var serialQueue: Task<Void, Never> = Task {}

  private init(
    center: any UNUserNotificationCenterProtocol,
    settings: SettingsService
  ) {
    self.center = center
    self.settings = settings
    super.init()
  }

  static func createForTesting(
    center: any UNUserNotificationCenterProtocol,
    settings: SettingsService
  ) -> SnapshotReminderService {
    SnapshotReminderService(center: center, settings: settings)
  }

  // MARK: - Public API

  enum AuthorizationResult: Sendable, Equatable {
    case authorized
    case deniedInSystemSettings
    case registrationFailure
  }

  /// Registers the `snapshotReminder` notification category (with the
  /// "Remind Tomorrow" action). Safe to call multiple times.
  func registerCategories() {
    let snooze = UNNotificationAction(
      identifier: Self.snoozeActionIdentifier,
      title: String(localized: "Remind Tomorrow"),
      options: [])
    let category = UNNotificationCategory(
      identifier: Self.categoryIdentifier,
      actions: [snooze],
      intentIdentifiers: [],
      options: [])
    center.setNotificationCategories([category])
  }

  /// Current authorization status, as reported by the underlying center.
  func authorizationStatus() async -> UNAuthorizationStatus {
    await center.authorizationStatus()
  }

  func setEnabled(_ enabled: Bool) async -> AuthorizationResult {
    if !enabled {
      settings.snapshotReminderEnabled = false
      // Snoozes belong to the active session; clearing them on disable
      // prevents a later re-enable from surfacing forgotten snoozes.
      settings.activeSnoozes = []
      await reconcile()
      return .authorized
    }

    var status = await center.authorizationStatus()
    if status == .notDetermined {
      _ = try? await center.requestAuthorization(options: [.alert, .sound])
      status = await center.authorizationStatus()
    }

    if status == .authorized || status == .provisional {
      // Sticky flag — recorded even when we bail below, since the
      // authorization itself is still a fact.
      settings.hasNotificationsBeenAuthorized = true

      // OS prompt is a real suspension point. If the user toggled OFF
      // mid-prompt the calling task is cancelled; the explicit OFF must win.
      guard !Task.isCancelled else { return .authorized }

      settings.snapshotReminderEnabled = true
      await reconcile()
      return .authorized
    }

    guard !Task.isCancelled else { return .registrationFailure }

    settings.snapshotReminderEnabled = false
    await reconcile()
    if status == .denied && settings.hasNotificationsBeenAuthorized {
      return .deniedInSystemSettings
    }
    return .registrationFailure
  }

  func updateConfig(
    _ transform: (inout SnapshotReminderConfig) -> Void
  ) async {
    var config = settings.snapshotReminderConfig
    transform(&config)
    settings.snapshotReminderConfig = config
    await reconcile()
  }

  func recordSnooze(hoursFromNow: Int = 24) async {
    let fireAt = Date().addingTimeInterval(TimeInterval(hoursFromNow) * 3_600)
    var snoozes = settings.activeSnoozes
    snoozes.append(fireAt)
    settings.activeSnoozes = snoozes
    await reconcile()
  }

  func reconcileOnLaunch() async {
    if settings.notificationsArchitectureVersion < Self.currentArchitectureVersion {
      // Drop session-scoped state (snoozes scheduled by older code without
      // UserDefaults backing); reconcile sweeps `usernoted` itself.
      settings.activeSnoozes = []
      settings.notificationsArchitectureVersion =
        Self.currentArchitectureVersion
    }
    await reconcile()
  }

  /// Public so callers that already persisted state synchronously (e.g.
  /// the ViewModel's debounced edit path) can request a rebuild without
  /// a redundant mutator round-trip.
  func reconcile() async {
    let prior = serialQueue
    let task = Task { [weak self] in
      await prior.value
      await self?.performReconcile()
    }
    serialQueue = task
    await task.value
  }

  // MARK: - Private: reconciliation

  private func performReconcile() async {
    let now = Date()
    let active = settings.activeSnoozes.filter { $0 > now }
    if active.count != settings.activeSnoozes.count {
      settings.activeSnoozes = active
    }

    let pending = await center.pendingNotificationRequests()
    let ours =
      pending
      .map(\.identifier)
      .filter { $0.hasPrefix(Self.identifierPrefix) }
    if !ours.isEmpty {
      center.removePendingNotificationRequests(withIdentifiers: ours)
    }

    guard settings.snapshotReminderEnabled else { return }

    let status = await center.authorizationStatus()
    guard status == .authorized || status == .provisional else { return }

    let content = makeContent()
    for request in Self.makeRecurringRequests(
      for: settings.snapshotReminderConfig,
      content: content,
      from: now,
      calendar: .current)
    {
      try? await center.add(request)
    }
    for fireAt in active {
      try? await center.add(
        Self.makeSnoozeRequest(fireAt: fireAt, content: content, from: now))
    }
  }

  // MARK: - Content

  private func makeContent() -> UNNotificationContent {
    let content = UNMutableNotificationContent()
    content.title = String(localized: "AssetFlow Reminder")
    content.body = String(localized: "Time to add a new portfolio snapshot.")
    content.categoryIdentifier = Self.categoryIdentifier
    content.sound = .default
    return content
  }

  // MARK: - Pure scheduling math

  /// Pure function — same inputs always produce the same outputs.
  /// Identifiers are namespaced under `identifierPrefix`.
  static func makeRecurringRequests(
    for config: SnapshotReminderConfig,
    content: UNNotificationContent,
    from referenceDate: Date,
    calendar: Calendar
  ) -> [UNNotificationRequest] {
    switch config.frequency {
    case .daily:
      var components = DateComponents()
      components.hour = config.hour
      components.minute = config.minute
      let trigger = UNCalendarNotificationTrigger(
        dateMatching: components, repeats: true)
      return [
        UNNotificationRequest(
          identifier: recurringIdentifier(for: .daily),
          content: content,
          trigger: trigger)
      ]

    case .weekly:
      var components = DateComponents()
      components.hour = config.hour
      components.minute = config.minute
      components.weekday = config.weekday
      let trigger = UNCalendarNotificationTrigger(
        dateMatching: components, repeats: true)
      return [
        UNNotificationRequest(
          identifier: recurringIdentifier(for: .weekly),
          content: content,
          trigger: trigger)
      ]

    case .monthly:
      var components = DateComponents()
      components.hour = config.hour
      components.minute = config.minute
      components.day = config.dayOfMonth
      let trigger = UNCalendarNotificationTrigger(
        dateMatching: components, repeats: true)
      return [
        UNNotificationRequest(
          identifier: recurringIdentifier(for: .monthly),
          content: content,
          trigger: trigger)
      ]

    case .biweekly:
      return makeWindowedRequests(
        intervalDays: 14,
        anchorWeekday: config.weekday,
        config: config,
        content: content,
        referenceDate: referenceDate,
        calendar: calendar,
        identifierTag: "biweekly")

    case .interval:
      return makeWindowedRequests(
        intervalDays: max(1, config.intervalDays),
        anchorWeekday: nil,
        config: config,
        content: content,
        referenceDate: referenceDate,
        calendar: calendar,
        identifierTag: "interval")
    }
  }

  /// Single source of truth for the recurring-cadence identifier shape.
  /// Used by both `makeRecurringRequests` and tests.
  static func recurringIdentifier(
    for frequency: SnapshotReminderConfig.Frequency
  ) -> String {
    "\(identifierPrefix)\(frequency.rawValue)"
  }

  /// Used for cadences that can't be expressed as a single repeating
  /// `UNCalendarNotificationTrigger` (bi-weekly, custom interval): emits
  /// 8 non-repeating triggers spaced `intervalDays` apart starting from
  /// the first firing strictly after `referenceDate`.
  private static func makeWindowedRequests(
    intervalDays: Int,
    anchorWeekday: Int?,
    config: SnapshotReminderConfig,
    content: UNNotificationContent,
    referenceDate: Date,
    calendar: Calendar,
    identifierTag: String
  ) -> [UNNotificationRequest] {
    var matching = DateComponents()
    matching.hour = config.hour
    matching.minute = config.minute
    if let weekday = anchorWeekday {
      matching.weekday = weekday
    }
    guard
      let firstFiring = calendar.nextDate(
        after: referenceDate,
        matching: matching,
        matchingPolicy: .nextTimePreservingSmallerComponents)
    else {
      return []
    }

    var requests: [UNNotificationRequest] = []
    for offset in 0..<8 {
      guard
        let firing = calendar.date(
          byAdding: .day, value: intervalDays * offset, to: firstFiring)
      else { continue }
      var firingComponents = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute], from: firing)
      // Re-apply hour/minute to defend against DST gap dates the calendar
      // shifted; the trigger fires on the matched calendar instant.
      firingComponents.hour = config.hour
      firingComponents.minute = config.minute
      let trigger = UNCalendarNotificationTrigger(
        dateMatching: firingComponents, repeats: false)
      requests.append(
        UNNotificationRequest(
          identifier: "\(identifierPrefix)\(identifierTag).\(offset)",
          content: content,
          trigger: trigger))
    }
    return requests
  }

  static func makeSnoozeRequest(
    fireAt: Date,
    content: UNNotificationContent,
    from referenceDate: Date
  ) -> UNNotificationRequest {
    let interval = max(1, fireAt.timeIntervalSince(referenceDate))
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: interval, repeats: false)
    let identifier = "\(snoozeIdentifierPrefix)\(UUID().uuidString)"
    return UNNotificationRequest(
      identifier: identifier, content: content, trigger: trigger)
  }
}

// MARK: - UNUserNotificationCenterDelegate

extension SnapshotReminderService: UNUserNotificationCenterDelegate {
  /// Show the banner even when AssetFlow is foregrounded, and keep the
  /// reminder in Notification Center so the user can still find it after
  /// the banner auto-dismisses.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }

  /// Routes a notification interaction:
  /// - the **Remind Tomorrow** action → `recordSnooze()`;
  /// - the default tap (or any unknown action) → `AppRouter.requestNewSnapshot()`.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    let actionID = response.actionIdentifier
    await MainActor.run { [weak self] in
      guard let self else { return }
      switch actionID {
      case Self.snoozeActionIdentifier:
        Task { [weak self] in await self?.recordSnooze() }

      default:
        AppRouter.shared.requestNewSnapshot()
      }
    }
  }
}
