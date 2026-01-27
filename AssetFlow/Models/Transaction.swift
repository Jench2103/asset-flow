//
//  Transaction.swift
//  AssetFlow
//
//  Created by Jen-Chien Chang on 2025/10/6.
//

import Foundation
import SwiftData

@Model
final class Transaction {
  var id: UUID
  var transactionType: TransactionType
  var transactionDate: Date
  var quantity: Decimal
  var pricePerUnit: Decimal
  var totalAmount: Decimal
  var currency: String
  var fees: Decimal?
  var notes: String?

  // Relationships
  @Relationship
  var asset: Asset?

  var sourceAsset: Asset?

  // For swap transactions: bidirectional link to the paired transaction.
  var relatedTransaction: Transaction?

  init(
    id: UUID = UUID(),
    transactionType: TransactionType,
    transactionDate: Date,
    quantity: Decimal,
    pricePerUnit: Decimal,
    totalAmount: Decimal,
    currency: String = "USD",
    fees: Decimal? = nil,
    notes: String? = nil,
    asset: Asset? = nil,
    sourceAsset: Asset? = nil,
    relatedTransaction: Transaction? = nil
  ) {
    self.id = id
    self.transactionType = transactionType
    self.transactionDate = transactionDate
    self.quantity = quantity
    self.pricePerUnit = pricePerUnit
    self.totalAmount = totalAmount
    self.currency = currency
    self.fees = fees
    self.notes = notes
    self.asset = asset
    self.sourceAsset = sourceAsset
    self.relatedTransaction = relatedTransaction
  }

  // Computed Properties

  /// The impact on asset quantity. Sells and transfers out decrease quantity.
  var quantityImpact: Decimal {
    switch transactionType {
    case .sell, .transferOut:
      return -quantity

    case .buy, .transferIn, .adjustment, .dividend, .interest:
      return quantity
    }
  }
}

enum TransactionType: String, Codable, CaseIterable {
  case buy = "Buy"
  case sell = "Sell"
  case transferIn = "Transfer In"
  case transferOut = "Transfer Out"
  case adjustment = "Adjustment"
  case dividend = "Dividend"
  case interest = "Interest"
}

extension TransactionType {
  var localizedName: String {
    switch self {
    case .buy: return String(localized: "Buy")
    case .sell: return String(localized: "Sell")
    case .transferIn: return String(localized: "Transfer In")
    case .transferOut: return String(localized: "Transfer Out")
    case .adjustment: return String(localized: "Adjustment")
    case .dividend: return String(localized: "Dividend")
    case .interest: return String(localized: "Interest")
    }
  }
}
