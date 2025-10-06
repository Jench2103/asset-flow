//
//  InvestmentPlan.swift
//  AssetFlow
//
//  Created by Jen-Chien Chang on 2025/10/6.
//

import Foundation
import SwiftData

@Model
final class InvestmentPlan {
  var id: UUID
  var name: String
  var planDescription: String?
  var startDate: Date
  var endDate: Date?
  var targetAmount: Decimal?
  var monthlyContribution: Decimal?
  var riskTolerance: RiskLevel
  var status: PlanStatus
  var notes: String?
  var createdDate: Date
  var lastUpdated: Date

  init(
    id: UUID = UUID(),
    name: String,
    planDescription: String? = nil,
    startDate: Date,
    endDate: Date? = nil,
    targetAmount: Decimal? = nil,
    monthlyContribution: Decimal? = nil,
    riskTolerance: RiskLevel = .moderate,
    status: PlanStatus = .active,
    notes: String? = nil
  ) {
    self.id = id
    self.name = name
    self.planDescription = planDescription
    self.startDate = startDate
    self.endDate = endDate
    self.targetAmount = targetAmount
    self.monthlyContribution = monthlyContribution
    self.riskTolerance = riskTolerance
    self.status = status
    self.notes = notes
    self.createdDate = Date()
    self.lastUpdated = Date()
  }
}

enum RiskLevel: String, Codable, CaseIterable {
  case veryLow = "Very Low"
  case low = "Low"
  case moderate = "Moderate"
  case high = "High"
  case veryHigh = "Very High"
}

enum PlanStatus: String, Codable, CaseIterable {
  case active = "Active"
  case paused = "Paused"
  case completed = "Completed"
  case cancelled = "Cancelled"
}
