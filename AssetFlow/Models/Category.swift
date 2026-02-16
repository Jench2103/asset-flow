//
//  Category.swift
//  AssetFlow
//
//  Created by Claude on 2026/02/14.
//

import Foundation
import SwiftData

@Model
final class Category {
  #Unique<Category>([\.name])

  var id: UUID
  var name: String
  var targetAllocationPercentage: Decimal?

  @Relationship(deleteRule: .deny, inverse: \Asset.category)
  var assets: [Asset]?

  init(
    name: String,
    targetAllocationPercentage: Decimal? = nil
  ) {
    self.id = UUID()
    self.name = name
    self.targetAllocationPercentage = targetAllocationPercentage
    self.assets = []
  }
}
