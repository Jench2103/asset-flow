//
//  PortfolioListViewModelTests.swift
//  AssetFlowTests
//
//  Created by Gemini on 2025/10/10.
//

import Foundation
import Testing

@testable import AssetFlow

/// Tests for PortfolioListViewModel
///
/// These tests verify that the ViewModel correctly manages portfolio data
/// and provides the necessary data for the PortfolioListView.
@Suite("PortfolioListViewModel Tests")
struct PortfolioListViewModelTests {

  // MARK: - Initialization Tests

  /// Test that the ViewModel initializes with mock portfolio data
  ///
  /// Corresponds to ticket objective:
  /// "Unit Test: The PortfolioListViewModel correctly fetches and provides a list of mock portfolios to the view."
  @Test("ViewModel initializes with mock portfolios")
  func viewModelInitializesWithMockPortfolios() {
    // Arrange & Act
    let viewModel = PortfolioListViewModel()

    // Assert
    #expect(viewModel.portfolios.count == 3, "ViewModel should initialize with 3 mock portfolios")
    #expect(!viewModel.portfolios.isEmpty, "Portfolios array should not be empty")
  }

  @Test("Mock portfolios have expected names")
  func mockPortfoliosHaveExpectedNames() {
    // Arrange & Act
    let viewModel = PortfolioListViewModel()

    // Assert
    #expect(
      viewModel.portfolios[0].name == "Tech Stocks", "First portfolio should be 'Tech Stocks'")
    #expect(
      viewModel.portfolios[1].name == "Real Estate", "Second portfolio should be 'Real Estate'")
    #expect(
      viewModel.portfolios[2].name == "Retirement Fund",
      "Third portfolio should be 'Retirement Fund'"
    )
  }

  @Test("Mock portfolios have descriptions")
  func mockPortfoliosHaveDescriptions() {
    // Arrange & Act
    let viewModel = PortfolioListViewModel()

    // Assert
    #expect(
      viewModel.portfolios[0].portfolioDescription == "High-growth tech portfolio",
      "First portfolio should have correct description"
    )
    #expect(
      viewModel.portfolios[1].portfolioDescription == "Residential properties",
      "Second portfolio should have correct description"
    )
    #expect(
      viewModel.portfolios[2].portfolioDescription == "Long-term investments",
      "Third portfolio should have correct description"
    )
  }

  // MARK: - Portfolio Properties Tests

  @Test("Mock portfolios are active by default")
  func mockPortfoliosAreActiveByDefault() {
    // Arrange & Act
    let viewModel = PortfolioListViewModel()

    // Assert
    for portfolio in viewModel.portfolios {
      #expect(portfolio.isActive == true, "All mock portfolios should be active")
    }
  }

  @Test("Mock portfolios have creation dates")
  func mockPortfoliosHaveCreationDates() {
    // Arrange & Act
    let viewModel = PortfolioListViewModel()

    // Assert
    let now = Date()
    for portfolio in viewModel.portfolios {
      #expect(
        portfolio.createdDate <= now,
        "Portfolio creation date should not be in the future"
      )
    }
  }

  @Test("Mock portfolios have unique IDs")
  func mockPortfoliosHaveUniqueIDs() {
    // Arrange & Act
    let viewModel = PortfolioListViewModel()

    // Assert
    let ids = Set(viewModel.portfolios.map { $0.id })
    #expect(
      ids.count == viewModel.portfolios.count,
      "Each portfolio should have a unique ID"
    )
  }

  // MARK: - Portfolio Computed Properties Tests

  @Test("Mock portfolios return zero total value when no assets")
  func mockPortfoliosReturnZeroTotalValueWhenNoAssets() {
    // Arrange & Act
    let viewModel = PortfolioListViewModel()

    // Assert
    for portfolio in viewModel.portfolios {
      #expect(
        portfolio.totalValue == 0,
        "Portfolio with no assets should have zero total value"
      )
    }
  }

  // MARK: - Observable Tests

  @Test("ViewModel is observable")
  func viewModelIsObservable() {
    // Arrange & Act
    let viewModel = PortfolioListViewModel()

    // Assert
    // The @Observable macro makes the class observable
    // This test verifies the class is instantiable and the portfolios property is accessible
    #expect(viewModel.portfolios.count == 3)
  }
}
