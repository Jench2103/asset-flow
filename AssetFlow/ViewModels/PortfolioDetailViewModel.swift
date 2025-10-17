//
//  PortfolioDetailViewModel.swift
//  AssetFlow
//
//  Created by Claude on 2025/10/18.
//

import Foundation
import SwiftData

/// ViewModel for the Portfolio Detail screen
///
/// Manages the display of a portfolio's assets and calculates aggregated values.
@Observable
final class PortfolioDetailViewModel {
  /// The portfolio being displayed
  let portfolio: Portfolio

  /// The model context for data operations
  let modelContext: ModelContext

  init(portfolio: Portfolio, modelContext: ModelContext) {
    self.portfolio = portfolio
    self.modelContext = modelContext
  }

  // MARK: - Computed Properties

  /// All assets belonging to this portfolio
  var assets: [Asset] {
    portfolio.assets ?? []
  }

  /// Total value of all assets in the portfolio
  var totalValue: Decimal {
    portfolio.totalValue
  }

  /// Number of assets in the portfolio
  var assetCount: Int {
    portfolio.assetCount
  }
}
