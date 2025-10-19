//
//  Portfolio.swift
//  AssetFlow
//
//  Created by Jen-Chien Chang on 2025/10/6.
//

import Foundation
import SwiftData

@Model
final class Portfolio {
  var id: UUID
  var name: String
  var portfolioDescription: String?
  var createdDate: Date
  var targetAllocation: [String: Decimal]?  // AssetType: percentage
  var isActive: Bool

  // Relationships
  // Note: .deny delete rule has known bugs in SwiftData and doesn't work reliably.
  // Using .nullify instead. Business logic MUST check isEmpty before allowing deletion.
  @Relationship(deleteRule: .nullify, inverse: \Asset.portfolio)
  var assets: [Asset]?

  init(
    id: UUID = UUID(),
    name: String,
    portfolioDescription: String? = nil,
    targetAllocation: [String: Decimal]? = nil,
    isActive: Bool = true
  ) {
    self.id = id
    self.name = name
    self.portfolioDescription = portfolioDescription
    self.createdDate = Date()
    self.targetAllocation = targetAllocation
    self.isActive = isActive
  }

  // Computed Properties

  /// Number of assets in this portfolio
  var assetCount: Int {
    assets?.count ?? 0
  }

  /// Returns true if the portfolio has no assets and can be deleted
  var isEmpty: Bool {
    assets?.isEmpty ?? true
  }
}
