# Testing Strategy

## Overview

This document outlines the testing strategy for AssetFlow, covering unit testing, integration testing, and UI testing for a SwiftUI + SwiftData application.

**Current Status**: The foundational infrastructure for isolated, in-memory testing for both unit and UI tests is implemented.

______________________________________________________________________

## Testing Philosophy

### Core Principles

1. **Test-Driven Development (TDD)**: Write tests before or alongside implementation when practical.
1. **Pyramid Structure**: More unit tests, fewer integration tests, minimal UI tests.
1. **Fast Feedback**: Tests should run quickly and provide clear failure messages.
1. **Isolation**: Each test must run in a completely isolated environment and not depend on the state of others.
1. **Maintainability**: Tests are code and must be kept clean and well-organized.

### Testing Pyramid

```
        ┌─────────────┐
        │  UI Tests   │  ← Fewer (slow, brittle)
        │   (E2E)     │
        ├─────────────┤
        │ Integration │  ← Some (moderate speed)
        │   Tests     │
        ├─────────────┤
        │    Unit     │  ← Many (fast, reliable)
        │   Tests     │
        └─────────────┘
```

______________________________________________________________________

## Testing Frameworks

This project uses a hybrid approach to testing, leveraging the best framework for each type of test.

### Unit & Integration Tests: Swift Testing

For all unit and integration tests, we use the modern **Swift Testing** framework. Its clean macro-based syntax (`@Test`, `@Suite`, `#expect`) is preferred for all logic, model, and data layer testing.

### UI Tests: XCTest

For UI tests, we use Apple's traditional **XCTest** framework, as it provides the necessary `XCUIApplication` APIs for interacting with the application's user interface from a separate process.

______________________________________________________________________

## Unit & Integration Testing with SwiftData

To ensure robust and reliable tests, every single test function (`@Test`) that requires a database must create its own dedicated, in-memory `ModelContainer`. This provides perfect isolation.

### Test Data Manager

We use a simple factory pattern in `TestDataManager.swift` to create these containers.

```swift
// In AssetFlowTests/TestDataManager.swift
@MainActor
class TestDataManager {
    static func createInMemoryContainer() -> ModelContainer {
        let schema = Schema([
            Portfolio.self, Asset.self, Transaction.self, InvestmentPlan.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: [configuration])
        return container
    }
}
```

### Example: Model Test

This example shows a test for a model's computed property. The test creates its own container, populates it with the necessary data, and asserts the outcome.

```swift
@Suite("Portfolio Model Tests")
@MainActor
struct PortfolioModelTests {
    @Test("totalValue sums the currentValue of its assets")
    func totalValue_SumsCurrentValueOfAssets() throws {
        // 1. Create a dedicated container for this test
        let container = TestDataManager.createInMemoryContainer()
        let context = container.mainContext

        // 2. Arrange: Create and insert models
        let portfolio = Portfolio(name: "Test Portfolio")
        let asset1 = Asset(name: "Stock A", assetType: .stock, currentValue: 1250.50, purchaseDate: Date())
        let asset2 = Asset(name: "Stock B", assetType: .stock, currentValue: 3000.25, purchaseDate: Date())
        portfolio.assets = [asset1, asset2]
        context.insert(portfolio)
        context.insert(asset1)
        context.insert(asset2)

        // 3. Act: Access the computed property
        let totalValue = portfolio.totalValue

        // 4. Assert: Check the result
        #expect(totalValue == 4250.75)
    }
}
```

### Example: ViewModel Test

ViewModels that use SwiftData should accept a `ModelContext` in their initializer. This allows us to inject the context from our in-memory container during testing.

```swift
@Suite("PortfolioListViewModel Tests")
@MainActor
struct PortfolioListViewModelTests {
    @Test("fetchPortfolios returns all items from the store")
    func fetchPortfolios_WhenStoreHasData_ReturnsPortfolios() throws {
        // 1. Create a dedicated container and context
        let container = TestDataManager.createInMemoryContainer()
        let context = container.mainContext

        // 2. Arrange: Insert data and initialize the ViewModel
        context.insert(Portfolio(name: "Portfolio 1"))
        context.insert(Portfolio(name: "Portfolio 2"))
        let viewModel = PortfolioListViewModel(modelContext: context)

        // 3. Act: Call the method to be tested
        viewModel.fetchPortfolios()

        // 4. Assert: Check the ViewModel's state
        #expect(viewModel.portfolios.count == 2)
    }
}
```

______________________________________________________________________

## UI Testing

UI tests run in a separate process and cannot directly access the application's code or inject a `ModelContainer`. Instead, we use **launch arguments** to instruct the app on how to configure itself for a test run.

### Launch Argument Strategy

1. **The Test Sets Arguments:** Before launching the app, the UI test adds strings to `app.launchArguments`.
1. **The App Responds:** The `AssetFlowApp` checks for these strings on startup and configures its `ModelContainer` accordingly.

This ensures every UI test starts with a fresh, clean in-memory database.

### Example: UI Test Setup

The UI test class uses a helper method to launch the app with specific arguments for each test, guaranteeing isolation.

```swift
// In a UI test file like PortfolioListViewUITests.swift
final class PortfolioListViewUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
    }

    private func launch(with arguments: [String] = ["UI-Testing"]) {
        app.launchArguments = arguments
        app.launch()
    }

    func testPortfolioListRendersWithMockData() throws {
        // Launches the app with a pre-populated in-memory database
        launch()
        XCTAssertTrue(app.staticTexts["Tech Stocks"].exists)
    }

    func testPortfolioListDisplaysEmptyState() throws {
        // Launches the app with an empty in-memory database
        launch(with: ["UI-Testing", "EmptyPortfolios"])
        XCTAssertTrue(app.staticTexts["No portfolios yet"].exists)
    }
}
```

### Example: App Response

The `AssetFlowApp` contains logic to handle these arguments.

```swift
// In AssetFlowApp.swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([...])
    var modelConfiguration: ModelConfiguration

    if CommandLine.arguments.contains("UI-Testing") {
        modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    } else {
        modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
    }

    let container = try! ModelContainer(for: schema, configurations: [modelConfiguration])

    // Pre-populate data for the default UI test case
    if CommandLine.arguments.contains("UI-Testing")
        && !CommandLine.arguments.contains("EmptyPortfolios") {
        // ... code to insert mock portfolios ...
    }

    return container
}()
```

______________________________________________________________________

## Test Data and Previews

### Test Utilities

- **Unit/Integration Tests:** Use `TestDataManager.createInMemoryContainer()` to create a clean database for each test.
- **SwiftUI Previews:** Use the `PreviewContainer` utility to provide a dedicated in-memory container for Xcode Previews. This keeps preview data separate from test data.

### Test Fixtures

For creating complex model instances, use test fixtures defined in extensions.

```swift
// Example for future use
extension Portfolio {
    static func withAssets(_ count: Int, in context: ModelContext) -> Portfolio {
        let portfolio = Portfolio(name: "Test Portfolio")
        for i in 0..<count {
            let asset = Asset(name: "Asset \(i)", ..., portfolio: portfolio)
            context.insert(asset)
        }
        return portfolio
    }
}
```

______________________________________________________________________

## Test Coverage

### Coverage Goals

| Layer      | Target Coverage       |
| ---------- | --------------------- |
| Models     | 90%+                  |
| ViewModels | 80%+                  |
| Services   | 85%+                  |
| Views      | 50%+ (critical paths) |
| Overall    | 75%+                  |

### Enabling Coverage

1. Edit Scheme → Test
1. Options → Code Coverage → ✓ Gather coverage for `AssetFlow` target.
1. Run tests and view results in the Report Navigator (`⌘9`).

______________________________________________________________________

## Best Practices

- **Test Behavior, Not Implementation:** Focus on what the code *does*, not how it does it.
- **One Assertion Per Test:** Ideal for clarity, but group related assertions when necessary.
- **Arrange-Act-Assert:** Structure tests clearly.
- **Independence:** Tests must not rely on each other.
- **Avoid Testing Frameworks:** Don't test SwiftData or SwiftUI internals.
- **Write Regression Tests:** When fixing a bug, write a test that fails before the fix and passes after.
