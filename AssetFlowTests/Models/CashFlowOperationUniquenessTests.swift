//
//  CashFlowOperationUniquenessTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/16.
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
