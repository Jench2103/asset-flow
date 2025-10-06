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
  var asset: Asset?

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
    asset: Asset? = nil
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
  }
}

enum TransactionType: String, Codable, CaseIterable {
  case buy = "Buy"
  case sell = "Sell"
  case dividend = "Dividend"
  case interest = "Interest"
  case deposit = "Deposit"
  case withdrawal = "Withdrawal"
  case transfer = "Transfer"
}
