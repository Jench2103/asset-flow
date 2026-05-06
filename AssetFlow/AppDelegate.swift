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

import AppKit
import UserNotifications

/// Handles macOS application lifecycle events that must run before
/// `WindowGroup` views appear.
///
/// In particular, `UNUserNotificationCenterDelegate` must be installed during
/// `applicationDidFinishLaunching(_:)` so that a notification tap that cold-
/// launches the app reliably delivers its response. Doing this from a
/// `WindowGroup` `.task` is too late — `.task` runs after launch completes,
/// and the deferred response can race against view-state initialization.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
  func applicationDidFinishLaunching(_ notification: Notification) {
    let reminderService = SnapshotReminderService.shared
    UNUserNotificationCenter.current().delegate = reminderService
    reminderService.registerCategories()
  }
}
