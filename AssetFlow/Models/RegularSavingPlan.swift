//
//  RegularSavingPlan.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/15.
//

import Foundation
import SwiftData

@Model
final class RegularSavingPlan {
  var id: UUID
  var name: String
  var amount: Decimal
  var frequency: SavingPlanFrequency
  var startDate: Date
  var nextDueDate: Date
  var executionMethod: SavingPlanExecutionMethod
  var isActive: Bool

  // Relationships
  @Relationship(deleteRule: .nullify)
  var asset: Asset?

  @Relationship(deleteRule: .nullify)
  var sourceAsset: Asset?

  init(
    id: UUID = UUID(),
    name: String,
    amount: Decimal,
    frequency: SavingPlanFrequency,
    startDate: Date,
    nextDueDate: Date,
    executionMethod: SavingPlanExecutionMethod,
    isActive: Bool = true,
    asset: Asset? = nil,
    sourceAsset: Asset? = nil
  ) {
    self.id = id
    self.name = name
    self.amount = amount
    self.frequency = frequency
    self.startDate = startDate
    self.nextDueDate = nextDueDate
    self.executionMethod = executionMethod
    self.isActive = isActive
    self.asset = asset
    self.sourceAsset = sourceAsset
  }
}

enum SavingPlanFrequency: String, Codable, CaseIterable {
  case daily = "Daily"
  case weekly = "Weekly"
  case biweekly = "Biweekly"
  case monthly = "Monthly"
}

enum SavingPlanExecutionMethod: String, Codable, CaseIterable {
  case automatic = "Automatic"
  case manual = "Manual"
}
