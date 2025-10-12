//
//  PortfolioListViewUITests.swift
//  AssetFlowUITests
//
//  Created by Gemini on 2025/10/10.
//

import XCTest

/// UI tests for PortfolioListView
///
/// These tests verify the user interface and interactions for the Portfolio List screen,
/// including list rendering, empty states, and navigation actions.
///
/// **Platform Focus:** macOS (primary), with iOS/iPadOS support planned
final class PortfolioListViewUITests: XCTestCase {

  var app: XCUIApplication!

  override func setUpWithError() throws {
    continueAfterFailure = false
    // Initialize the app, but do not launch it here.
    // Each test will be responsible for launching with its own configuration.
    app = XCUIApplication()
  }

  override func tearDownWithError() throws {
    // Terminate the app after each test to ensure a clean slate for the next one.
    app.terminate()
    app = nil
  }

  // MARK: - Helper Methods

  /// Launches the application with a specific set of launch arguments.
  /// - Parameter arguments: The launch arguments to use for this specific launch.
  private func launch(with arguments: [String] = ["UI-Testing"]) {
    app.launchArguments = arguments
    app.launch()
  }

  // MARK: - Portfolio List Rendering Tests

  /// Test that the view correctly renders a list of mock portfolios provided by the ViewModel
  ///
  /// Corresponds to ticket objective:
  /// "UI Test: The view correctly renders a list of mock portfolios provided by the ViewModel."
  func testPortfolioListRendersWithMockData() throws {
    // Given: App is launched with default mock data
    launch()

    // Then: The list should display all mock portfolios
    #if os(macOS)
      let portfolioList =
        app.tables.firstMatch.exists
        ? app.tables.firstMatch
        : app.outlines.firstMatch
    #else
      let portfolioList =
        app.collectionViews.firstMatch.exists
        ? app.collectionViews.firstMatch
        : app.tables.firstMatch
    #endif

    XCTAssertTrue(portfolioList.waitForExistence(timeout: 5), "Portfolio list should appear")
    XCTAssertTrue(
      app.staticTexts["Tech Stocks"].exists, "Portfolio 'Tech Stocks' should be displayed")
    XCTAssertTrue(
      app.staticTexts["Real Estate"].exists, "Portfolio 'Real Estate' should be displayed")
    XCTAssertTrue(
      app.staticTexts["Retirement Fund"].exists, "Portfolio 'Retirement Fund' should be displayed")
  }

  func testPortfolioListShowsPortfolioDescriptions() throws {
    // Given: App is launched with default mock data
    launch()

    // Then: Portfolio descriptions should be visible
    XCTAssertTrue(app.staticTexts["High-growth tech portfolio"].exists)
    XCTAssertTrue(app.staticTexts["Residential properties"].exists)
    XCTAssertTrue(app.staticTexts["Long-term investments"].exists)
  }

  // MARK: - Empty State Tests

  /// Test that the view displays a specific message or view when the list of portfolios is empty
  ///
  /// Corresponds to ticket objective:
  /// "UI Test: The view displays a specific message or view when the list of portfolios is empty."
  func testPortfolioListDisplaysEmptyState() throws {
    // Given: App is launched with no portfolios
    launch(with: ["UI-Testing", "EmptyPortfolios"])

    // Then: An empty state message should be displayed
    let emptyStateMessage = app.staticTexts["No portfolios yet"]
    XCTAssertTrue(
      emptyStateMessage.waitForExistence(timeout: 5), "Empty state message should be displayed")
  }

  func testEmptyStateHasHelpfulText() throws {
    // Given: App is launched with empty portfolio list
    launch(with: ["UI-Testing", "EmptyPortfolios"])

    // Then: Helpful guidance text should be displayed
    let helpText = app.staticTexts["Add your first portfolio to get started"]
    XCTAssertTrue(helpText.waitForExistence(timeout: 5), "Empty state should contain helpful text")
  }

  // MARK: - Add Portfolio Button Tests

  /// Test that tapping the "Add Portfolio" button correctly triggers the navigation action
  ///
  /// Corresponds to ticket objective:
  /// "UI Test: Tapping the 'Add Portfolio' button correctly triggers the navigation action."
  func testTappingAddPortfolioButtonTriggersNavigation() throws {
    // Given: App is launched
    launch()

    // When: User taps/clicks the "Add Portfolio" button
    #if os(macOS)
      let addButton = app.toolbars.buttons["Add Portfolio"].firstMatch
    #else
      let addButton = app.buttons["Add Portfolio"].firstMatch
    #endif

    XCTAssertTrue(addButton.waitForExistence(timeout: 5), "Add Portfolio button should be visible")
    addButton.tap()

    // Then: The app should navigate to the Add Portfolio screen.
    // We verify this by checking for the existence of the "Save" button on the destination view.
    let saveButton = app.buttons["Save"]
    XCTAssertTrue(
      saveButton.waitForExistence(timeout: 2),
      "Should navigate to Add Portfolio screen and show Save button")
  }
}
