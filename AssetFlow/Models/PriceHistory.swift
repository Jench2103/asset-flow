//
//  PriceHistory.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/15.
//

import Foundation
import SwiftData

@Model
final class PriceHistory {
  var id: UUID
  var date: Date
  var price: Decimal

  // Relationships
  @Relationship
  var asset: Asset?

  init(
    id: UUID = UUID(),
    date: Date,
    price: Decimal,
    asset: Asset? = nil
  ) {
    self.id = id
    self.date = date
    self.price = price
    self.asset = asset
  }
}
