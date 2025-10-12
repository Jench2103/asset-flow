//
//  PortfolioListViewModelTests.swift
//  AssetFlowTests
//
//  Created by Gemini on 2025/10/10.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

/// Tests for PortfolioListViewModel
///
/// These tests verify that the ViewModel correctly fetches and manages portfolio data
/// from a SwiftData ModelContext.
@Suite("PortfolioListViewModel Tests")
@MainActor
struct PortfolioListViewModelTests {

  @Test("ViewModel initializes with an empty portfolio list")
  func viewModelInitializesEmpty() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Act
    let viewModel = PortfolioListViewModel(modelContext: context)

    // Assert
    #expect(
      viewModel.portfolios.isEmpty, "ViewModel should initialize with an empty portfolios array")
  }

  @Test("fetchPortfolios returns empty array when store is empty")
  func fetchPortfolios_WhenStoreIsEmpty_ReturnsEmptyArray() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioListViewModel(modelContext: context)

    // Act
    viewModel.fetchPortfolios()

    // Assert
    #expect(viewModel.portfolios.isEmpty, "Portfolios array should be empty")
  }

  @Test("fetchPortfolios returns all items from the store")
  func fetchPortfolios_WhenStoreHasData_ReturnsPortfolios() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioListViewModel(modelContext: context)

    let portfolio1 = Portfolio(name: "First Portfolio", portfolioDescription: "")
    let portfolio2 = Portfolio(name: "Second Portfolio", portfolioDescription: "")
    context.insert(portfolio1)
    context.insert(portfolio2)

    // Act
    viewModel.fetchPortfolios()

    // Assert
    #expect(viewModel.portfolios.count == 2, "ViewModel should fetch all 2 portfolios")
  }

  @Test("fetchPortfolios returns items sorted by name")
  func fetchPortfolios_ReturnsItemsSortedByName() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioListViewModel(modelContext: context)

    let portfolioC = Portfolio(name: "C Portfolio", portfolioDescription: "")
    let portfolioA = Portfolio(name: "A Portfolio", portfolioDescription: "")
    let portfolioB = Portfolio(name: "B Portfolio", portfolioDescription: "")
    context.insert(portfolioC)
    context.insert(portfolioA)
    context.insert(portfolioB)

    // Act
    viewModel.fetchPortfolios()

    // Assert
    #expect(viewModel.portfolios.count == 3)
    #expect(viewModel.portfolios[0].name == "A Portfolio", "First item should be A")
    #expect(viewModel.portfolios[1].name == "B Portfolio", "Second item should be B")
    #expect(viewModel.portfolios[2].name == "C Portfolio", "Third item should be C")
  }
}
