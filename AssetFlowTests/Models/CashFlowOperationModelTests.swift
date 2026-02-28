//
//  CashFlowOperationModelTests.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("CashFlowOperation Model Tests")
@MainActor
struct CashFlowOperationModelTests {

  // MARK: - Creation and Properties

  @Test("CashFlowOperation initializes with description and amount")
  func testInitializesWithDescriptionAndAmount() {
    let op = CashFlowOperation(cashFlowDescription: "Monthly deposit", amount: Decimal(5000))
    #expect(op.cashFlowDescription == "Monthly deposit")
    #expect(op.amount == Decimal(5000))
    #expect(op.snapshot == nil)
  }

  @Test("CashFlowOperation persists in SwiftData context")
  func testPersistsInContext() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let op = CashFlowOperation(cashFlowDescription: "Salary deposit", amount: Decimal(8000))
    context.insert(op)

    let descriptor = FetchDescriptor<CashFlowOperation>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.count == 1)
    #expect(fetched.first?.cashFlowDescription == "Salary deposit")
    #expect(fetched.first?.amount == Decimal(8000))
  }

  // MARK: - Positive and Negative Amounts

  @Test("Positive amount represents inflow (deposit)")
  func testPositiveAmountRepresentsInflow() {
    let op = CashFlowOperation(cashFlowDescription: "Deposit", amount: Decimal(10000))
    #expect(op.amount > 0)
  }

  @Test("Negative amount represents outflow (withdrawal)")
  func testNegativeAmountRepresentsOutflow() {
    let op = CashFlowOperation(cashFlowDescription: "Withdrawal", amount: Decimal(-3000))
    #expect(op.amount < 0)
  }

  @Test("Zero amount is accepted")
  func testZeroAmountIsAccepted() {
    let op = CashFlowOperation(cashFlowDescription: "No-op transfer", amount: Decimal(0))
    #expect(op.amount == Decimal(0))
  }

  @Test("Zero amount persists in context")
  func testZeroAmountPersistsInContext() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let op = CashFlowOperation(cashFlowDescription: "Zero transfer", amount: Decimal(0))
    context.insert(op)

    let descriptor = FetchDescriptor<CashFlowOperation>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.first?.amount == Decimal(0))
  }

  // MARK: - Decimal Precision

  @Test("Amount preserves Decimal precision")
  func testAmountPreservesDecimalPrecision() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let preciseAmount = try #require(Decimal(string: "12345.6789"))
    let op = CashFlowOperation(cashFlowDescription: "Precise deposit", amount: preciseAmount)
    context.insert(op)

    let descriptor = FetchDescriptor<CashFlowOperation>()
    let fetched = try context.fetch(descriptor)
    #expect(fetched.first?.amount == preciseAmount)
  }

  // MARK: - Relationship

  @Test("CashFlowOperation links to snapshot")
  func testLinksToSnapshot() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let snapshot = Snapshot(date: Date())
    let op = CashFlowOperation(cashFlowDescription: "Deposit", amount: Decimal(5000))

    context.insert(snapshot)
    context.insert(op)
    op.snapshot = snapshot

    #expect(op.snapshot === snapshot)
    #expect(
      snapshot.cashFlowOperations?.contains(where: { $0.cashFlowDescription == "Deposit" }) == true)
  }

  @Test("Multiple operations in the same snapshot")
  func testMultipleOperationsInSameSnapshot() throws {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    let snapshot = Snapshot(date: Date())
    context.insert(snapshot)

    let deposit = CashFlowOperation(cashFlowDescription: "Deposit", amount: Decimal(10000))
    let withdrawal = CashFlowOperation(cashFlowDescription: "Withdrawal", amount: Decimal(-3000))

    context.insert(deposit)
    context.insert(withdrawal)

    deposit.snapshot = snapshot
    withdrawal.snapshot = snapshot

    #expect(snapshot.cashFlowOperations?.count == 2)
  }
}
