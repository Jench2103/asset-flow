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

/// Minimal seam over `UNUserNotificationCenter` so `SnapshotReminderService`
/// can be exercised in unit tests without touching the system center.
///
/// Production code calls `UNUserNotificationCenter.current()` (extended below
/// to conform). Tests inject a fake that records calls and returns canned
/// authorization statuses.
@MainActor
protocol UNUserNotificationCenterProtocol: AnyObject {
  func authorizationStatus() async -> UNAuthorizationStatus
  func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
  func setNotificationCategories(_ categories: Set<UNNotificationCategory>)
  func add(_ request: UNNotificationRequest) async throws
  func pendingNotificationRequests() async -> [UNNotificationRequest]
  func removePendingNotificationRequests(withIdentifiers identifiers: [String])
  func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?)
}

extension UNUserNotificationCenter: UNUserNotificationCenterProtocol {
  func authorizationStatus() async -> UNAuthorizationStatus {
    await notificationSettings().authorizationStatus
  }

  func setDelegate(_ delegate: (any UNUserNotificationCenterDelegate)?) {
    self.delegate = delegate
  }
}
