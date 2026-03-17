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
import SwiftData
import Testing

@testable import AssetFlow

@Suite("CashFlowOperation Uniqueness Constraints")
@MainActor
struct CashFlowOperationUniquenessTests {

  @Test("CashFlowOperation enforces unique (snapshot, description) constraint — duplicate upserts")
  func cashFlowEnforcesDatabaseUniqueness() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Create snapshot
    let snapshot = Snapshot(date: Date())
    context.insert(snapshot)
    try context.save()

    // Create first cash flow
    let cf1 = CashFlowOperation(
      cashFlowDescription: "Salary deposit",
      amount: Decimal(50000)
    )
    cf1.snapshot = snapshot
    context.insert(cf1)
    try context.save()

    // Attempt duplicate (same snapshot, same description)
    let cf2 = CashFlowOperation(
      cashFlowDescription: "Salary deposit",
      amount: Decimal(30000)  // Different amount, but same description
    )
    cf2.snapshot = snapshot
    context.insert(cf2)
    try context.save()

    // With #Unique constraint, should only have 1 cash flow (upsert behavior)
    let descriptor = FetchDescriptor<AssetFlow.CashFlowOperation>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.count == 1)
  }

  @Test("CashFlowOperation allows same description on different snapshots")
  func cashFlowAllowsSameDescriptionDifferentSnapshot() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Create two snapshots
    let snapshot1 = Snapshot(date: Date())
    let snapshot2 = Snapshot(date: Date().addingTimeInterval(86400))
    context.insert(snapshot1)
    context.insert(snapshot2)
    try context.save()

    // Same description, different snapshots - should be allowed
    let cf1 = CashFlowOperation(
      cashFlowDescription: "Salary deposit",
      amount: Decimal(50000)
    )
    cf1.snapshot = snapshot1

    let cf2 = CashFlowOperation(
      cashFlowDescription: "Salary deposit",
      amount: Decimal(50000)
    )
    cf2.snapshot = snapshot2

    context.insert(cf1)
    context.insert(cf2)
    try context.save()

    // Both should exist as separate records
    let descriptor = FetchDescriptor<AssetFlow.CashFlowOperation>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.count == 2)

    // Verify they have different persistent IDs
    #expect(cf1.persistentModelID != cf2.persistentModelID)
  }
}
