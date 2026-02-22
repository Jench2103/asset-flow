//
//  CashFlowOperation.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation
import SwiftData

@Model
final class CashFlowOperation {
  #Unique<CashFlowOperation>([\.snapshot, \.cashFlowDescription])

  var id: UUID
  var cashFlowDescription: String
  var amount: Decimal
  var currency: String

  @Relationship
  var snapshot: Snapshot?

  init(
    cashFlowDescription: String,
    amount: Decimal
  ) {
    self.id = UUID()
    self.cashFlowDescription = cashFlowDescription
    self.amount = amount
    self.currency = ""
    self.snapshot = nil
  }
}
