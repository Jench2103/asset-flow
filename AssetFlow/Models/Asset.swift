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
    var currentValue: Decimal
    var purchaseDate: Date
    var purchasePrice: Decimal?
    var quantity: Decimal
    var currency: String
    var notes: String?
    var lastUpdated: Date

    // Relationships
    var portfolio: Portfolio?
    var transactions: [Transaction]?

    init(
        id: UUID = UUID(),
        name: String,
        assetType: AssetType,
        currentValue: Decimal,
        purchaseDate: Date,
        purchasePrice: Decimal? = nil,
        quantity: Decimal = 1.0,
        currency: String = "USD",
        notes: String? = nil,
        portfolio: Portfolio? = nil
    ) {
        self.id = id
        self.name = name
        self.assetType = assetType
        self.currentValue = currentValue
        self.purchaseDate = purchaseDate
        self.purchasePrice = purchasePrice
        self.quantity = quantity
        self.currency = currency
        self.notes = notes
        self.lastUpdated = Date()
        self.portfolio = portfolio
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
