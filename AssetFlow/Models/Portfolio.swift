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
    var targetAllocation: [String: Decimal]? // AssetType: percentage
    var isActive: Bool

    // Relationships
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

    var totalValue: Decimal {
        assets?.reduce(0) { $0 + $1.currentValue } ?? 0
    }
}
