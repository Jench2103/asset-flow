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
    app = XCUIApplication()
    app.launchArguments = ["UI-Testing"]  // Configure for testing environment
    app.launch()
  }

  override func tearDownWithError() throws {
    app = nil
  }

  // MARK: - Portfolio List Rendering Tests

  /// Test that the view correctly renders a list of mock portfolios provided by the ViewModel
  ///
  /// Corresponds to ticket objective:
  /// "UI Test: The view correctly renders a list of mock portfolios provided by the ViewModel."
  func testPortfolioListRendersWithMockData() throws {
    // Given: App is launched with mock data
    // The PortfolioListViewModel should provide mock portfolios

    // When: User views the portfolio list
    // Note: On macOS, Lists often appear as tables or outlines
    // On iOS, they appear as collectionViews or tables

    // Then: The list should display all mock portfolios
    #if os(macOS)
      // macOS: Lists appear as tables or outlines in the accessibility hierarchy
      let portfolioList =
        app.tables.firstMatch.exists
        ? app.tables.firstMatch
        : app.outlines.firstMatch
    #else
      // iOS/iPadOS: Lists appear as collectionViews or tables
      let portfolioList =
        app.collectionViews.firstMatch.exists
        ? app.collectionViews.firstMatch
        : app.tables.firstMatch
    #endif

    // Wait for the list to appear
    XCTAssertTrue(
      portfolioList.waitForExistence(timeout: 5),
      "Portfolio list should appear"
    )

    // Verify that portfolio names are displayed
    // Note: Use staticTexts to find text elements regardless of platform
    XCTAssertTrue(
      app.staticTexts["Tech Stocks"].exists,
      "Portfolio 'Tech Stocks' should be displayed in the list"
    )

    XCTAssertTrue(
      app.staticTexts["Real Estate"].exists,
      "Portfolio 'Real Estate' should be displayed in the list"
    )

    XCTAssertTrue(
      app.staticTexts["Retirement Fund"].exists,
      "Portfolio 'Retirement Fund' should be displayed in the list"
    )
  }

  func testPortfolioListShowsPortfolioDescriptions() throws {
    // Given: App is launched with mock data

    // Then: Portfolio descriptions should be visible
    XCTAssertTrue(
      app.staticTexts["High-growth tech portfolio"].exists,
      "First portfolio description should be visible"
    )

    XCTAssertTrue(
      app.staticTexts["Residential properties"].exists,
      "Second portfolio description should be visible"
    )

    XCTAssertTrue(
      app.staticTexts["Long-term investments"].exists,
      "Third portfolio description should be visible"
    )
  }

  func testPortfolioListHasCorrectNumberOfItems() throws {
    // Given: App is launched with mock data (3 portfolios)

    // Then: All portfolio names should be present
    let portfolioNames = ["Tech Stocks", "Real Estate", "Retirement Fund"]
    for name in portfolioNames {
      XCTAssertTrue(
        app.staticTexts[name].exists,
        "Portfolio '\(name)' should be displayed"
      )
    }
  }

  // MARK: - Empty State Tests

  /// Test that the view displays a specific message or view when the list of portfolios is empty
  ///
  /// Corresponds to ticket objective:
  /// "UI Test: The view displays a specific message or view when the list of portfolios is empty."
  func testPortfolioListDisplaysEmptyState() throws {
    // Given: App is launched with no portfolios
    // Note: This test will need the app to support a test mode with empty data
    app.launchArguments = ["UI-Testing", "EmptyPortfolios"]
    app.launch()

    // Then: An empty state message should be displayed
    let emptyStateMessage = app.staticTexts["No portfolios yet"]
    XCTAssertTrue(
      emptyStateMessage.waitForExistence(timeout: 5),
      "Empty state message should be displayed when no portfolios exist"
    )
  }

  func testEmptyStateHasHelpfulText() throws {
    // Given: App is launched with empty portfolio list
    app.launchArguments = ["UI-Testing", "EmptyPortfolios"]
    app.launch()

    // Then: Helpful guidance text should be displayed
    let helpText = app.staticTexts["Add your first portfolio to get started"]
    XCTAssertTrue(
      helpText.exists,
      "Empty state should contain helpful text about adding portfolios"
    )
  }

  func testEmptyStateHasIcon() throws {
    // Given: App is launched with empty portfolio list
    app.launchArguments = ["UI-Testing", "EmptyPortfolios"]
    app.launch()

    // Then: An icon or image should be visible in the empty state
    // On macOS and iOS, SF Symbols render as images
    let emptyStateIcon = app.images.firstMatch
    XCTAssertTrue(
      emptyStateIcon.waitForExistence(timeout: 5),
      "Empty state should display an icon"
    )
  }

  // MARK: - Add Portfolio Button Tests

  /// Test that tapping the "Add Portfolio" button correctly triggers the navigation action
  ///
  /// Corresponds to ticket objective:
  /// "UI Test: Tapping the 'Add Portfolio' button correctly triggers the navigation action."
  func testAddPortfolioButtonExists() throws {
    // Given: App is launched and portfolio list is visible

    // Then: An "Add Portfolio" button should be present
    #if os(macOS)
      // On macOS, look in the toolbar
      let toolbar = app.toolbars.firstMatch
      XCTAssertTrue(
        toolbar.waitForExistence(timeout: 5),
        "Toolbar should exist on macOS"
      )
      let addButton = toolbar.buttons["Add Portfolio"]
      XCTAssertTrue(
        addButton.exists,
        "Add Portfolio button should be visible in toolbar"
      )
    #else
      // On iOS, it could be in the navigation bar or as a floating action button
      let addButton = app.buttons["Add Portfolio"]
      XCTAssertTrue(
        addButton.waitForExistence(timeout: 5),
        "Add Portfolio button should be visible"
      )
    #endif
  }

  func testTappingAddPortfolioButtonTriggersNavigation() throws {
    // Given: App is launched and portfolio list is visible
    #if os(macOS)
      let toolbar = app.toolbars.firstMatch
      let addButton = toolbar.buttons["Add Portfolio"].firstMatch
      XCTAssertTrue(
        addButton.waitForExistence(timeout: 5),
        "Add Portfolio button should be visible"
      )
    #else
      let addButton = app.buttons["Add Portfolio"].firstMatch
      XCTAssertTrue(
        addButton.waitForExistence(timeout: 5),
        "Add Portfolio button should be visible"
      )
    #endif

    // When: User taps/clicks the "Add Portfolio" button
    addButton.tap()

    // Then: The app should navigate to the Add Portfolio screen
    // Look for form elements that indicate we're on an add/edit screen
    let cancelButton = app.buttons["Cancel"]
    let saveButton = app.buttons["Save"]

    // Wait a moment for navigation to complete
    sleep(1)

    // At least one of these should exist on an add/edit form
    XCTAssertTrue(
      cancelButton.exists || saveButton.exists,
      "Add Portfolio form should be displayed with Cancel or Save buttons"
    )
  }

  func testAddPortfolioButtonAccessibilityLabel() throws {
    // Given: App is launched

    #if os(macOS)
      // On macOS, find the button in the toolbar to avoid ambiguity
      let toolbar = app.toolbars.firstMatch
      XCTAssertTrue(
        toolbar.waitForExistence(timeout: 5),
        "Toolbar should exist on macOS"
      )

      let addButton = toolbar.buttons["Add Portfolio"].firstMatch
      XCTAssertTrue(
        addButton.exists,
        "Add Portfolio button should exist in toolbar with proper accessibility label"
      )

      XCTAssertTrue(
        addButton.isEnabled,
        "Add Portfolio button should be enabled"
      )
    #else
      // On iOS, button can be queried directly
      let addButton = app.buttons["Add Portfolio"].firstMatch
      XCTAssertTrue(
        addButton.waitForExistence(timeout: 5),
        "Add Portfolio button should exist with proper accessibility label"
      )
    #endif
  }

  // MARK: - Portfolio Row Interaction Tests

  func testTappingPortfolioRowNavigatesToDetail() throws {
    // Given: Portfolio list is visible with mock data
    // Find the first portfolio by its name
    let firstPortfolio = app.staticTexts["Tech Stocks"]
    XCTAssertTrue(
      firstPortfolio.waitForExistence(timeout: 5),
      "First portfolio should be visible"
    )

    // When: User taps/clicks on a portfolio row
    #if os(macOS)
      // On macOS, might need to click the row or double-click
      firstPortfolio.click()
    #else
      firstPortfolio.tap()
    #endif

    // Then: The app should navigate to the portfolio detail screen
    // Note: Actual behavior depends on implementation
    // For now, verify the app responds (navigation or selection occurs)

    // This is a placeholder - actual assertion will depend on implementation
    // For example, checking for a detail view or highlighted selection
  }

  // MARK: - Platform-Specific Tests

  func testPortfolioListIsAdaptiveToScreenSize() throws {
    // Given: App is launched
    // Note: This test verifies that the layout adapts to the platform

    #if os(macOS)
      // On macOS, expect a table or outline view
      let hasTable = app.tables.firstMatch.exists
      let hasOutline = app.outlines.firstMatch.exists
      XCTAssertTrue(
        hasTable || hasOutline,
        "Portfolio list should appear as table or outline on macOS"
      )
    #else
      // On iOS/iPadOS, expect a collection view or table
      let hasCollection = app.collectionViews.firstMatch.exists
      let hasTable = app.tables.firstMatch.exists
      XCTAssertTrue(
        hasCollection || hasTable,
        "Portfolio list should appear as collection or table on iOS"
      )
    #endif
  }

  #if os(macOS)
    func testMacOSToolbarContainsAddButton() throws {
      // Given: App is launched on macOS
      // Then: The toolbar should contain an Add Portfolio button
      let toolbar = app.toolbars.firstMatch
      XCTAssertTrue(
        toolbar.waitForExistence(timeout: 5),
        "Toolbar should exist on macOS"
      )

      let addButton = toolbar.buttons["Add Portfolio"]
      XCTAssertTrue(
        addButton.exists,
        "Add Portfolio button should be in the toolbar on macOS"
      )
    }

    func testMacOSSidebarShowsPortfoliosSection() throws {
      // Given: App is launched on macOS
      // Note: macOS uses sidebar navigation as per UserInterfaceDesign.md

      // Then: A sidebar should exist with a "Portfolios" section
      // This test is for future implementation when sidebar is added
      // let sidebar = app.splitGroups.firstMatch
      // XCTAssertTrue(sidebar.exists, "Sidebar should exist on macOS")
    }
  #endif

  // MARK: - Search Functionality Tests (Future)

  func testSearchFieldExists() throws {
    // Given: Portfolio list is visible
    // Note: Search functionality may be added in future iterations

    // Then: A search field should be present (if implemented)
    // This test will be enabled when search is implemented
    // let searchField = app.searchFields.firstMatch
    // XCTAssertTrue(searchField.exists, "Search field should be present")
  }

  // MARK: - Performance Tests

  func testPortfolioListLoadsQuickly() throws {
    // Measure the time it takes for the portfolio list to appear
    measure(metrics: [XCTClockMetric()]) {
      app.launch()

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

      _ = portfolioList.waitForExistence(timeout: 5)
    }
  }
}
