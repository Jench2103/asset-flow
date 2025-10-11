//
//  PortfolioListViewModel.swift
//  AssetFlow
//
//  Created by Gemini on 2025/10/10.
//

import Foundation
import Observation

/// ViewModel for managing portfolio list data
///
/// This ViewModel provides mock data for the MVP phase.
/// In future iterations, it will fetch data from SwiftData.
@Observable
class PortfolioListViewModel {
  var portfolios: [Portfolio] = []

  /// Initialize the ViewModel with mock data
  ///
  /// Checks for test launch arguments:
  /// - "EmptyPortfolios" - Initializes with empty portfolio list for testing empty state
  /// - Otherwise - Initializes with mock data
  init() {
    // Check if running in test mode with empty portfolios
    if CommandLine.arguments.contains("EmptyPortfolios") {
      // Empty for testing empty state
      self.portfolios = []
    } else {
      // Default mock data
      self.portfolios = [
        Portfolio(name: "Tech Stocks", portfolioDescription: "High-growth tech portfolio"),
        Portfolio(name: "Real Estate", portfolioDescription: "Residential properties"),
        Portfolio(name: "Retirement Fund", portfolioDescription: "Long-term investments"),
      ]
    }
  }

  // MARK: - Future Implementation

  // TODO: Replace with SwiftData @Query when implementing persistence
  // func loadPortfolios() async {
  //     // Fetch from SwiftData
  // }
}
