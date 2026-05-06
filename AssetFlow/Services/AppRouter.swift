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

/// Lightweight in-process signal bus for routing notification taps to the
/// New Snapshot dialog.
///
/// `SnapshotReminderService.userNotificationCenter(_:didReceive:)` calls
/// `requestNewSnapshot()`, which sets a fresh UUID token. `ContentView`
/// observes the token and switches the sidebar to **Snapshots**;
/// `SnapshotListView` observes the same token to open its create-snapshot
/// sheet, then calls `consumeNewSnapshotRequest()` to clear it.
///
/// A UUID token (rather than a `Bool`) is used so that two consecutive
/// requests produce two distinct values, ensuring `.onChange` fires both
/// times.
@Observable
@MainActor
final class AppRouter {
  static let shared = AppRouter()
  private init() {}

  static func createForTesting() -> AppRouter { AppRouter() }

  private(set) var pendingNewSnapshotToken: UUID?

  func requestNewSnapshot() {
    pendingNewSnapshotToken = UUID()
  }

  func consumeNewSnapshotRequest() {
    pendingNewSnapshotToken = nil
  }

  /// Whether the UI should route the user to the New Snapshot sheet right
  /// now. Returns `false` when the app is locked — the caller leaves the
  /// token parked so the request can be replayed after authentication, which
  /// avoids surfacing the sheet above the lock overlay.
  func shouldRouteNewSnapshotNow(isLocked: Bool) -> Bool {
    !isLocked && pendingNewSnapshotToken != nil
  }
}
