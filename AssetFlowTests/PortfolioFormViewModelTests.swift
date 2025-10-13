//
//  PortfolioFormViewModelTests.swift
//  AssetFlowTests
//
//  Created by Gemini on 2025/10/13.
//

import SwiftData
import Testing

@testable import AssetFlow

@Suite("PortfolioFormViewModel Tests")
@MainActor
struct PortfolioFormViewModelTests {
  @Test("ViewModel initializes correctly for a new portfolio")
  func testInitForNewPortfolio() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext

    // Act
    let viewModel = PortfolioFormViewModel(modelContext: context)

    // Assert
    #expect(viewModel.name.isEmpty)
    #expect(viewModel.portfolioDescription.isEmpty)
    #expect(viewModel.isEditing == false)
  }

  @Test("ViewModel initializes correctly for an existing portfolio")
  func testInitForExistingPortfolio() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let existingPortfolio = Portfolio(name: "Existing", portfolioDescription: "My Desc")
    context.insert(existingPortfolio)

    // Act
    let viewModel = PortfolioFormViewModel(modelContext: context, portfolio: existingPortfolio)

    // Assert
    #expect(viewModel.name == "Existing")
    #expect(viewModel.portfolioDescription == "My Desc")
    #expect(viewModel.isEditing == true)
  }

  @Test("isSaveDisabled is true when name is empty")
  func testIsSaveDisabledTrueWhenNameEmpty() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioFormViewModel(modelContext: context)

    // Act
    viewModel.name = ""

    // Assert
    #expect(viewModel.isSaveDisabled == true)
  }

  @Test("isSaveDisabled is true when name is only whitespace")
  func testIsSaveDisabledTrueWhenNameIsWhitespace() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioFormViewModel(modelContext: context)

    // Act
    viewModel.name = "   "

    // Assert
    #expect(viewModel.isSaveDisabled == true)
  }

  @Test("isSaveDisabled is false when name is not empty")
  func testIsSaveDisabledFalseWhenNameNotEmpty() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioFormViewModel(modelContext: context)

    // Act
    viewModel.name = "My Portfolio"

    // Assert
    #expect(viewModel.isSaveDisabled == false)
  }

  @Test("save() creates a new portfolio")
  func testSaveCreatesNewPortfolio() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let viewModel = PortfolioFormViewModel(modelContext: context)
    viewModel.name = "New Portfolio"
    viewModel.portfolioDescription = "New Description"

    // Act
    viewModel.save()

    // Assert
    let fetchDescriptor = FetchDescriptor<Portfolio>()
    let portfolios = try context.fetch(fetchDescriptor)

    #expect(portfolios.count == 1)
    let portfolio = try #require(portfolios.first)
    #expect(portfolio.name == "New Portfolio")
    #expect(portfolio.portfolioDescription == "New Description")
  }

  @Test("save() updates an existing portfolio")
  func testSaveUpdatesExistingPortfolio() throws {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let existingPortfolio = Portfolio(name: "Original Name", portfolioDescription: "Original Desc")
    context.insert(existingPortfolio)

    let viewModel = PortfolioFormViewModel(modelContext: context, portfolio: existingPortfolio)
    viewModel.name = "Updated Name"
    viewModel.portfolioDescription = "Updated Desc"

    // Act
    viewModel.save()

    // Assert
    let fetchDescriptor = FetchDescriptor<Portfolio>()
    let portfolios = try context.fetch(fetchDescriptor)

    #expect(portfolios.count == 1)
    let portfolio = try #require(portfolios.first)
    #expect(portfolio.name == "Updated Name")
    #expect(portfolio.portfolioDescription == "Updated Desc")
    #expect(portfolio.id == existingPortfolio.id)
  }

  // MARK: - Name Uniqueness Validation Tests

  @Test("isSaveDisabled is true for duplicate name on new portfolio (case-insensitive)")
  func testSaveDisabledForDuplicateName_NewPortfolio() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    context.insert(Portfolio(name: "Existing Portfolio"))

    let viewModel = PortfolioFormViewModel(modelContext: context)

    // Act
    viewModel.name = "existing portfolio"  // Different case

    // Assert
    #expect(viewModel.isSaveDisabled == true)
    #expect(viewModel.nameValidationMessage == "A portfolio with this name already exists.")
  }

  @Test("isSaveDisabled is false when editing a portfolio with its original name")
  func testSaveEnabled_EditingWithOriginalName() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolio = Portfolio(name: "My Portfolio")
    context.insert(portfolio)

    let viewModel = PortfolioFormViewModel(modelContext: context, portfolio: portfolio)

    // Act
    // Name is not changed

    // Assert
    #expect(viewModel.isSaveDisabled == false)
    #expect(viewModel.nameValidationMessage == nil)
  }

  @Test("isSaveDisabled is true when editing a portfolio name to match another existing portfolio")
  func testSaveDisabled_EditingToDuplicateOfAnother() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let portfolioA = Portfolio(name: "Portfolio A")
    let portfolioB = Portfolio(name: "Portfolio B")
    context.insert(portfolioA)
    context.insert(portfolioB)

    let viewModel = PortfolioFormViewModel(modelContext: context, portfolio: portfolioA)

    // Act
    viewModel.name = "Portfolio B"  // Change name to match portfolio B

    // Assert
    #expect(viewModel.isSaveDisabled == true)
    #expect(viewModel.nameValidationMessage == "A portfolio with this name already exists.")
  }
}
