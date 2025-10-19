//
//  Asset.swift
//  AssetFlow
//
//  Created by Jen-Chien Chang on 2025/10/6.
//

import Foundation
import SwiftData

@Model
final class Asset {
  var id: UUID
  var name: String
  var assetType: AssetType
  var currency: String
  var notes: String?

  // Relationships
  @Relationship
  var portfolio: Portfolio?

  @Relationship(deleteRule: .cascade, inverse: \Transaction.asset)
  var transactions: [Transaction]?

  @Relationship(deleteRule: .cascade, inverse: \PriceHistory.asset)
  var priceHistory: [PriceHistory]?

  init(
    id: UUID = UUID(),
    name: String,
    assetType: AssetType,
    currency: String = "USD",
    notes: String? = nil,
    portfolio: Portfolio? = nil
  ) {
    self.id = id
    self.name = name
    self.assetType = assetType
    self.currency = currency
    self.notes = notes
    self.portfolio = portfolio
  }

  // Computed Properties

  /// Current quantity held, calculated from transactions
  var quantity: Decimal {
    transactions?.reduce(0) { $0 + $1.quantityImpact } ?? 0
  }

  /// The most recent price from price history
  var currentPrice: Decimal {
    priceHistory?.sorted(by: { $0.date > $1.date }).first?.price ?? 0
  }

  /// Current total value of the asset
  var currentValue: Decimal {
    quantity * currentPrice
  }

  /// Average cost per unit, calculated from buy transactions
  var averageCost: Decimal {
    let totalCost =
      transactions?.filter { $0.transactionType == .buy }.reduce(0) { $0 + $1.totalAmount } ?? 0
    let totalQuantity =
      transactions?.filter { $0.transactionType == .buy }.reduce(0) { $0 + $1.quantity } ?? 0
    return totalQuantity > 0 ? totalCost / totalQuantity : 0
  }

  /// Total cost basis for current holdings
  var costBasis: Decimal {
    averageCost * quantity
  }

  /// Whether this asset is locked from editing type/currency
  /// Assets are locked if they have any associated transactions or price history
  var isLocked: Bool {
    (transactions?.isEmpty == false) || (priceHistory?.isEmpty == false)
  }
}

enum AssetType: String, Codable, CaseIterable {
  case stock = "Stock"
  case bond = "Bond"
  case crypto = "Cryptocurrency"
  case realEstate = "Real Estate"
  case commodity = "Commodity"
  case cash = "Cash"
  case mutualFund = "Mutual Fund"
  case etf = "ETF"
  case other = "Other"
}
