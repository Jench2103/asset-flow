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

/// Schedules and cancels local "remember to take a snapshot" notifications via
/// `UNUserNotificationCenter`.
///
/// The service owns notification authorization, category registration, and the
/// pending-request lifecycle. All scheduling math is in the pure `makeRequests`
/// function, which is exercised in isolation by unit tests. Reschedule is
/// idempotent: existing requests sharing the `identifierPrefix` are removed
/// before any new ones are added.
@Observable
@MainActor
final class SnapshotReminderService: NSObject {
  static let shared: SnapshotReminderService = .init(
    center: UNUserNotificationCenter.current()
  )

  static let categoryIdentifier = "snapshotReminder"
  static let snoozeActionIdentifier = "snooze"
  static let identifierPrefix = "snapshotReminder."
  static let snoozeIdentifierPrefix = "snapshotReminder.snooze."

  private let center: any UNUserNotificationCenterProtocol

  private init(center: any UNUserNotificationCenterProtocol) {
    self.center = center
    super.init()
  }

  static func createForTesting(center: any UNUserNotificationCenterProtocol)
    -> SnapshotReminderService
  {
    SnapshotReminderService(center: center)
  }

  // MARK: - Public surface

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

  /// Prompts the user for authorization (if not yet determined) and returns
  /// the resulting status. Returns the existing status when the request itself
  /// throws (e.g. user already decided).
  func requestAuthorization() async -> UNAuthorizationStatus {
    do {
      _ = try await center.requestAuthorization(options: [.alert, .sound])
    } catch {
      // The center reports the canonical status regardless; ignore.
    }
    return await center.authorizationStatus()
  }

  /// Cancels any existing snapshot-reminder requests and, if `config` is
  /// non-nil and notifications are authorized, schedules the new ones.
  /// Idempotent — safe to call repeatedly without producing duplicates.
  func reschedule(config: SnapshotReminderConfig?) async {
    let pending = await center.pendingNotificationRequests()
    // Wipe snoozes only when the user is fully disabling reminders. A
    // recurring-schedule reschedule (config != nil) preserves any pending
    // "Remind Tomorrow" snooze the user explicitly opted into.
    let toRemove =
      pending
      .map(\.identifier)
      .filter {
        guard $0.hasPrefix(Self.identifierPrefix) else { return false }
        if config != nil, $0.hasPrefix(Self.snoozeIdentifierPrefix) {
          return false
        }
        return true
      }
    if !toRemove.isEmpty {
      center.removePendingNotificationRequests(withIdentifiers: toRemove)
    }

    guard let config else { return }
    let status = await center.authorizationStatus()
    guard status == .authorized || status == .provisional else { return }

    let requests = Self.makeRequests(
      for: config,
      content: makeContent(),
      from: Date(),
      calendar: .current)

    for request in requests {
      do {
        try await center.add(request)
      } catch {
        // Logged to console only — keep the rest of the schedule intact.
      }
    }
  }

  /// One-shot reminder N hours from now. Does not touch the recurring
  /// schedule.
  func snooze(by hours: Int = 24) async {
    let trigger = UNTimeIntervalNotificationTrigger(
      timeInterval: TimeInterval(hours) * 3_600,
      repeats: false)
    let identifier = "\(Self.snoozeIdentifierPrefix)\(UUID().uuidString)"
    let request = UNNotificationRequest(
      identifier: identifier,
      content: makeContent(),
      trigger: trigger)
    do {
      try await center.add(request)
    } catch {
      // ignored — best-effort
    }
  }

  /// Phase-preserving launch refresh.
  ///
  /// Unlike `reschedule`, this never replaces an in-phase schedule. For
  /// daily/weekly/monthly cadences it ensures the single repeating trigger is
  /// present. For windowed cadences (biweekly, custom interval) it counts
  /// future pending slots and only extends the window from the latest existing
  /// slot when fewer than ``windowTargetCount`` remain. Crucially, this means
  /// opening the app one day after a bi-weekly Monday reminder fires no
  /// longer collapses the next gap from 14 days to 7.
  func topUpScheduleIfNeeded(config: SnapshotReminderConfig) async {
    let status = await center.authorizationStatus()
    guard status == .authorized || status == .provisional else { return }

    let pending = await center.pendingNotificationRequests()
    let recurring = pending.filter {
      $0.identifier.hasPrefix(Self.identifierPrefix)
        && !$0.identifier.hasPrefix(Self.snoozeIdentifierPrefix)
    }

    switch config.frequency {
    case .daily, .weekly, .monthly:
      let expectedID = Self.recurringIdentifier(for: config.frequency)
      guard !recurring.contains(where: { $0.identifier == expectedID }) else {
        return
      }
      // Schedule fresh — `reschedule` is safe here because there are no
      // in-phase requests to disturb.
      await reschedule(config: config)

    case .biweekly, .interval:
      await topUpWindowedSchedule(config: config, existing: recurring)
    }
  }

  /// Number of future windowed slots we aim to keep pending. Eight slots gives
  /// ~16 weeks of bi-weekly headroom and ~8×N days for custom intervals.
  private static let windowTargetCount = 8

  private func topUpWindowedSchedule(
    config: SnapshotReminderConfig,
    existing: [UNNotificationRequest]
  ) async {
    let now = Date()
    let calendar = Calendar.current
    let intervalDays =
      config.frequency == .biweekly ? 14 : max(1, config.intervalDays)
    let prefix = "\(Self.identifierPrefix)\(config.frequency.rawValue)."
    let myFrequencyExisting = existing.filter {
      $0.identifier.hasPrefix(prefix)
    }

    let futureFireDates: [Date] =
      myFrequencyExisting
      .compactMap { request -> Date? in
        guard
          let trigger = request.trigger as? UNCalendarNotificationTrigger,
          let date = calendar.date(from: trigger.dateComponents),
          date > now
        else { return nil }
        return date
      }
      .sorted()

    let needToAdd = Self.windowTargetCount - futureFireDates.count
    guard needToAdd > 0 else { return }

    let firstNewSlot: Date
    if let lastExisting = futureFireDates.last {
      // Continue the existing schedule's phase.
      firstNewSlot =
        calendar.date(byAdding: .day, value: intervalDays, to: lastExisting) ?? now
    } else {
      // No in-phase anchor available; start from the next matching time.
      var matching = DateComponents()
      matching.hour = config.hour
      matching.minute = config.minute
      if config.frequency == .biweekly {
        matching.weekday = config.weekday
      }
      firstNewSlot =
        calendar.nextDate(
          after: now,
          matching: matching,
          matchingPolicy: .nextTimePreservingSmallerComponents) ?? now
    }

    let content = makeContent()
    for offset in 0..<needToAdd {
      guard
        let fireDate = calendar.date(
          byAdding: .day, value: intervalDays * offset, to: firstNewSlot)
      else { continue }
      var components = calendar.dateComponents(
        [.year, .month, .day, .hour, .minute], from: fireDate)
      components.hour = config.hour
      components.minute = config.minute
      let trigger = UNCalendarNotificationTrigger(
        dateMatching: components, repeats: false)
      let identifier = "\(prefix)\(UUID().uuidString)"
      let request = UNNotificationRequest(
        identifier: identifier, content: content, trigger: trigger)
      do {
        try await center.add(request)
      } catch {
        // ignored — best-effort
      }
    }
  }

  private static func recurringIdentifier(
    for frequency: SnapshotReminderConfig.Frequency
  ) -> String {
    "\(identifierPrefix)\(frequency.rawValue)"
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

  // MARK: - Scheduling math

  /// Builds the pending notification requests for the given configuration.
  ///
  /// Pure function — given the same inputs, always produces the same outputs.
  /// Identifiers are namespaced with `identifierPrefix` so they can be removed
  /// selectively without affecting unrelated notifications.
  static func makeRequests(
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
          identifier: "\(identifierPrefix)daily",
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
          identifier: "\(identifierPrefix)weekly",
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
          identifier: "\(identifierPrefix)monthly",
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

  /// Schedules a windowed sequence of 8 non-repeating triggers spaced
  /// `intervalDays` apart starting from the first firing strictly after
  /// `referenceDate`. Used by frequencies that cannot be expressed as a single
  /// repeating `UNCalendarNotificationTrigger` (bi-weekly, custom interval).
  ///
  /// The schedule is re-extended on each app launch and whenever the user
  /// touches reminder settings; `reschedule(config:)` is idempotent.
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
}

// MARK: - UNUserNotificationCenterDelegate

extension SnapshotReminderService: UNUserNotificationCenterDelegate {
  /// Show the banner even when AssetFlow is foregrounded, and keep the
  /// reminder in Notification Center so the user can still find it after the
  /// banner auto-dismisses. Background-delivered reminders are added to
  /// Notification Center by the system regardless of these options;
  /// foreground delivery is the only case `.list` matters for.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    willPresent notification: UNNotification
  ) async -> UNNotificationPresentationOptions {
    [.banner, .list, .sound]
  }

  /// Routes a notification interaction:
  /// - the **Remind Tomorrow** action → reschedule a one-shot 24h out;
  /// - the default tap (or any unknown action) → ask the app to open the
  ///   New Snapshot dialog via `AppRouter`.
  nonisolated func userNotificationCenter(
    _ center: UNUserNotificationCenter,
    didReceive response: UNNotificationResponse
  ) async {
    let actionID = response.actionIdentifier
    await MainActor.run { [weak self] in
      guard let self else { return }
      switch actionID {
      case Self.snoozeActionIdentifier:
        Task { [weak self] in await self?.snooze() }

      default:
        AppRouter.shared.requestNewSnapshot()
      }
    }
  }
}
