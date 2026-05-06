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

@Suite("AppRouter Tests")
@MainActor
struct AppRouterTests {

  @Test("Initial pendingNewSnapshotToken is nil")
  func initialTokenIsNil() {
    let router = AppRouter.createForTesting()
    #expect(router.pendingNewSnapshotToken == nil)
  }

  @Test("requestNewSnapshot() sets a non-nil token")
  func requestSetsNonNilToken() {
    let router = AppRouter.createForTesting()
    router.requestNewSnapshot()
    #expect(router.pendingNewSnapshotToken != nil)
  }

  @Test("Two consecutive requests produce different tokens")
  func tokensDifferAcrossRequests() {
    let router = AppRouter.createForTesting()
    router.requestNewSnapshot()
    let first = router.pendingNewSnapshotToken
    router.requestNewSnapshot()
    let second = router.pendingNewSnapshotToken
    #expect(first != nil)
    #expect(second != nil)
    #expect(first != second)
  }

  @Test("consumeNewSnapshotRequest clears the token to nil")
  func consumeClearsToken() {
    let router = AppRouter.createForTesting()
    router.requestNewSnapshot()
    #expect(router.pendingNewSnapshotToken != nil)
    router.consumeNewSnapshotRequest()
    #expect(router.pendingNewSnapshotToken == nil)
  }

  // MARK: - Lock-deferral gate

  @Test("shouldRouteNewSnapshotNow is false when no token is pending")
  func shouldRouteFalseWhenEmpty() {
    let router = AppRouter.createForTesting()
    #expect(router.shouldRouteNewSnapshotNow(isLocked: false) == false)
    #expect(router.shouldRouteNewSnapshotNow(isLocked: true) == false)
  }

  @Test("shouldRouteNewSnapshotNow defers when the app is locked")
  func shouldRouteDefersWhenLocked() {
    let router = AppRouter.createForTesting()
    router.requestNewSnapshot()
    #expect(router.shouldRouteNewSnapshotNow(isLocked: true) == false)
  }

  @Test("shouldRouteNewSnapshotNow drains once the app is unlocked")
  func shouldRouteFiresWhenUnlocked() {
    let router = AppRouter.createForTesting()
    router.requestNewSnapshot()
    #expect(router.shouldRouteNewSnapshotNow(isLocked: false) == true)
  }

  @Test("shouldRouteNewSnapshotNow leaves the token parked when locked")
  func parkedTokenSurvivesLockCheck() {
    let router = AppRouter.createForTesting()
    router.requestNewSnapshot()
    let parked = router.pendingNewSnapshotToken
    _ = router.shouldRouteNewSnapshotNow(isLocked: true)
    // Gate is read-only; a locked check must not consume the request.
    #expect(router.pendingNewSnapshotToken == parked)
  }
}
