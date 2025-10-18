//
//  PortfolioManagementViewModelTests.swift
//  AssetFlowTests
//
//  Created by Gemini on 2025/10/10.
//

import Foundation
import SwiftData
import Testing

@testable import AssetFlow

/// Tests for PortfolioManagementViewModel
@Suite("PortfolioManagementViewModel Tests")
@MainActor
struct PortfolioManagementViewModelTests {

  @Test("ViewModel initializes and holds the correct model context")
  func viewModelInitializesAndHoldsContext() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Act
    let viewModel = PortfolioManagementViewModel(modelContext: context)

    // Assert
    // Verify that the ViewModel correctly stores the context it was given.
    #expect(viewModel.modelContext === context)
  }

  // MARK: - Deletion Validation Tests

  @Test("Validation succeeds for empty portfolio")
  func validateDeletion_EmptyPortfolio_ReturnsSuccess() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioManagementViewModel(modelContext: context)

    let emptyPortfolio = Portfolio(name: "Empty Portfolio")
    context.insert(emptyPortfolio)

    // Act
    let result = viewModel.validateDeletion(of: emptyPortfolio)

    // Assert
    switch result {
    case .success:
      #expect(Bool(true), "Validation should succeed for empty portfolio")

    case .failure:
      Issue.record("Expected success but got failure")
    }
  }

  @Test("Validation fails for non-empty portfolio")
  func validateDeletion_NonEmptyPortfolio_ReturnsFailure() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioManagementViewModel(modelContext: context)

    let portfolio = Portfolio(name: "Tech Portfolio")
    let asset = Asset(name: "Apple", assetType: .stock, currency: "USD", portfolio: portfolio)

    context.insert(portfolio)
    context.insert(asset)

    // Act
    let result = viewModel.validateDeletion(of: portfolio)

    // Assert
    switch result {
    case .success:
      Issue.record("Expected failure but got success")

    case .failure(let error):
      if case .portfolioNotEmpty(let count) = error {
        #expect(count == 1, "Should report 1 asset")
      } else {
        Issue.record("Wrong error type")
      }
    }
  }

  @Test("Validation fails for portfolio with multiple assets")
  func validateDeletion_PortfolioWithMultipleAssets_ReturnsFailureWithCorrectCount() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioManagementViewModel(modelContext: context)

    let portfolio = Portfolio(name: "Diversified Portfolio")
    let asset1 = Asset(name: "Apple", assetType: .stock, portfolio: portfolio)
    let asset2 = Asset(name: "Microsoft", assetType: .stock, portfolio: portfolio)
    let asset3 = Asset(name: "Bitcoin", assetType: .crypto, portfolio: portfolio)

    context.insert(portfolio)
    context.insert(asset1)
    context.insert(asset2)
    context.insert(asset3)

    // Act
    let result = viewModel.validateDeletion(of: portfolio)

    // Assert
    switch result {
    case .success:
      Issue.record("Expected failure but got success")

    case .failure(let error):
      if case .portfolioNotEmpty(let count) = error {
        #expect(count == 3, "Should report 3 assets")
      } else {
        Issue.record("Wrong error type")
      }
    }
  }

  // MARK: - Initiate Delete Tests

  @Test("Initiating delete for empty portfolio shows confirmation")
  func initiateDelete_EmptyPortfolio_ShowsConfirmation() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioManagementViewModel(modelContext: context)

    let portfolio = Portfolio(name: "Empty Portfolio")
    context.insert(portfolio)

    // Act
    viewModel.initiateDelete(portfolio: portfolio)

    // Assert
    #expect(viewModel.showingDeleteConfirmation == true)
    #expect(viewModel.portfolioToDelete?.id == portfolio.id)
    #expect(viewModel.showingDeletionError == false)
  }

  @Test("Initiating delete for non-empty portfolio shows error")
  func initiateDelete_NonEmptyPortfolio_ShowsError() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioManagementViewModel(modelContext: context)

    let portfolio = Portfolio(name: "Tech Portfolio")
    let asset = Asset(name: "Apple", assetType: .stock, currency: "USD", portfolio: portfolio)

    context.insert(portfolio)
    context.insert(asset)

    // Act
    viewModel.initiateDelete(portfolio: portfolio)

    // Assert
    #expect(viewModel.showingDeletionError == true)
    #expect(viewModel.deletionError != nil)
    #expect(viewModel.showingDeleteConfirmation == false)
  }

  // MARK: - Confirm Delete Tests

  @Test("Confirming delete removes portfolio from context")
  func confirmDelete_ValidPortfolio_DeletesPortfolio() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioManagementViewModel(modelContext: context)

    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    // Verify portfolio exists
    let descriptor = FetchDescriptor<Portfolio>()
    var portfolios = try context.fetch(descriptor)
    #expect(portfolios.count == 1)

    // Set up for deletion
    viewModel.portfolioToDelete = portfolio
    viewModel.showingDeleteConfirmation = true

    // Act
    viewModel.confirmDelete()

    // Assert - portfolio should be deleted
    portfolios = try context.fetch(descriptor)
    #expect(portfolios.isEmpty)
    #expect(viewModel.portfolioToDelete == nil)
    #expect(viewModel.showingDeleteConfirmation == false)
  }

  @Test("Confirming delete for portfolio with assets shows error")
  func confirmDelete_PortfolioWithAssets_ShowsError() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioManagementViewModel(modelContext: context)

    let portfolio = Portfolio(name: "Tech Portfolio")
    let asset = Asset(name: "Apple", assetType: .stock, portfolio: portfolio)

    context.insert(portfolio)
    context.insert(asset)

    // Set up for deletion (simulating user bypassing validation somehow)
    viewModel.portfolioToDelete = portfolio
    viewModel.showingDeleteConfirmation = true

    // Act
    viewModel.confirmDelete()

    // Assert - should show error
    #expect(viewModel.showingDeletionError == true)
    #expect(viewModel.deletionError != nil)
  }

  // MARK: - Edge Case Tests

  @Test("Deletion fails if portfolio gains assets between validation and confirmation")
  func confirmDelete_PortfolioGainsAssets_ShowsError() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioManagementViewModel(modelContext: context)

    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    // Initiate deletion (portfolio is empty)
    viewModel.initiateDelete(portfolio: portfolio)
    #expect(viewModel.showingDeleteConfirmation == true)

    // Simulate asset being added while confirmation dialog is open
    let asset = Asset(name: "Apple", assetType: .stock, currency: "USD", portfolio: portfolio)
    context.insert(asset)

    // Act - user confirms deletion
    viewModel.confirmDelete()

    // Assert - should show error instead of deleting
    #expect(viewModel.showingDeletionError == true)
    #expect(viewModel.deletionError != nil)
  }

  // MARK: - Cancel Delete Tests

  @Test("Canceling delete resets state without deleting")
  func cancelDelete_ResetsState() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioManagementViewModel(modelContext: context)

    let portfolio = Portfolio(name: "Test Portfolio")
    context.insert(portfolio)

    viewModel.portfolioToDelete = portfolio
    viewModel.showingDeleteConfirmation = true

    // Act
    viewModel.cancelDelete()

    // Assert - state reset, portfolio still exists
    #expect(viewModel.portfolioToDelete == nil)
    #expect(viewModel.showingDeleteConfirmation == false)

    let descriptor = FetchDescriptor<Portfolio>()
    let portfolios = try context.fetch(descriptor)
    #expect(portfolios.count == 1)
  }
}
