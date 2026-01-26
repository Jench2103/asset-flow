# Testing Strategy

## Overview

This document outlines the testing strategy for AssetFlow, which prioritizes **Unit and ViewModel testing** to ensure logical correctness and maintain a fast, reliable test suite.

After careful consideration, the project has opted to **forgo UI testing**. The rationale is that a comprehensive suite of tests at the ViewModel layer provides sufficient confidence in the application's behavior, while avoiding the brittleness and maintenance overhead associated with UI tests.

**Current Status**: The foundational infrastructure for isolated, in-memory unit and ViewModel testing is implemented using the Swift Testing framework.

______________________________________________________________________

## Testing Philosophy

### Core Principles

1. **Test-Driven Development (TDD)**: Write tests before or alongside implementation when practical.
1. **Focused Testing**: Concentrate efforts on the lower, more stable layers of the testing pyramid (Unit and Integration/ViewModel tests).
1. **Fast Feedback**: Tests must run quickly and provide clear failure messages.
1. **Isolation**: Each test must run in a completely isolated environment and not depend on the state of others.
1. **Maintainability**: Tests are code and must be kept clean and well-organized.

### The Testing Pyramid (Our Approach)

While the traditional pyramid includes UI tests, we are intentionally focusing on the bottom two layers. By thoroughly testing the ViewModel, we verify the application's state and logic. We accept the trade-off of not testing the View layer's bindings directly, in exchange for a much faster and more stable test suite.

```
        ┌─────────────────┐
        │    UI Layer     │  ← Not tested automatically
        │     (Views)     │
        ├─────────────────┤
        │   ViewModel &   │  ← Primary focus: Test app
        │ Integration Tests │    logic and state here
        ├─────────────────┤
        │    Unit Tests   │  ← Foundation: Test models
        │ (Models, Utils) │    and business logic
        └─────────────────┘
```

______________________________________________________________________

## Testing Frameworks

This project uses the modern **Swift Testing** framework for all unit and integration tests. Its clean macro-based syntax (`@Test`, `@Suite`, `#expect`) is used for all logic, model, and ViewModel testing.

______________________________________________________________________

## Unit & ViewModel Testing with SwiftData

To ensure robust and reliable tests, every single test function (`@Test`) that requires a database must create its own dedicated, in-memory `ModelContainer`. This provides perfect isolation.

### Test Data Manager

We use a simple factory pattern in `TestDataManager.swift` to create these containers.

```swift
// In AssetFlowTests/TestDataManager.swift
@MainActor
class TestDataManager {
    static func createInMemoryContainer() -> ModelContainer {
        let schema = Schema([
            Portfolio.self, Asset.self, Transaction.self,
            InvestmentPlan.self, PriceHistory.self, RegularSavingPlan.self
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

ViewModels that use SwiftData should accept a `ModelContext` in their initializer. This allows us to inject the context from our in-memory container during testing, giving us full control over the ViewModel's environment.

```swift
@Suite("PortfolioManagementViewModel Tests")
@MainActor
struct PortfolioManagementViewModelTests {
    @Test("validateDeletion returns success for empty portfolio")
    func validateDeletion_EmptyPortfolio_ReturnsSuccess() throws {
        // 1. Create a dedicated container and context
        let container = TestDataManager.createInMemoryContainer()
        let context = container.mainContext

        // 2. Arrange: Insert data and initialize the ViewModel
        let portfolio = Portfolio(name: "Empty Portfolio")
        context.insert(portfolio)
        let viewModel = PortfolioManagementViewModel(modelContext: context)

        // 3. Act: Validate deletion
        let result = viewModel.validateDeletion(of: portfolio)

        // 4. Assert: Check the result
        #expect(result == .success(()))
    }
}
```

______________________________________________________________________

## Test Data and Previews

### Test Utilities

- **Unit/ViewModel Tests:** Use `TestDataManager.createInMemoryContainer()` to create a clean database for each test.
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

Our testing strategy emphasizes full coverage of the application's logic and data layers. The View layer is tested manually during development.

| Layer      | Target Coverage |
| ---------- | --------------- |
| Models     | 90%+            |
| ViewModels | 85%+            |
| Services   | 85%+            |
| Overall    | 80%+            |

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

______________________________________________________________________

## Implemented Test Suites

### ViewModel Tests

1. **PortfolioFormViewModelTests**

   - Portfolio creation and editing initialization
   - Name validation (empty, whitespace, uniqueness)
   - Save/update operations
   - User interaction tracking
   - Whitespace trimming warnings

1. **PortfolioManagementViewModelTests**

   - Portfolio listing
   - Portfolio deletion with validation
   - Empty state handling

1. **PortfolioDetailViewModelTests**

   - Asset list display
   - Total value calculation
   - Portfolio metadata

1. **AssetFormViewModelTests**

   - Asset creation and editing initialization
   - Name validation (empty, whitespace)
   - Quantity validation (required, numeric, positive)
   - Current value validation (required, numeric, non-negative)
   - Save operations for new and existing assets
   - User interaction tracking
   - Form state management
   - Cash asset: cost basis auto-set to 1, validation bypass, save with price = 1

1. **TransactionFormViewModelTests** (38 tests)

   - Default initialization and price pre-fill from asset
   - Date validation (today, past, future)
   - Quantity validation (empty, invalid, zero, negative, valid)
   - Price per unit validation (empty, invalid, negative, zero, valid)
   - Combined validation and save-disabled state
   - Auto-calculated total amount
   - Save creates transaction and updates asset quantity
   - Sell/transferOut quantity capped at current holdings
   - Cash asset display names ("Deposit"/"Withdrawal")
   - User interaction flag tracking
   - Edit mode: field pre-population, isEditing flag, navigationTitle
   - Edit mode: interaction flags set to true
   - Edit mode: quantity validation excludes current transaction's impact
   - Edit mode: resulting quantity must be >= 0
   - Edit mode: save updates in-place (no new insert, count unchanged)
   - Edit mode: cash asset price stays at 1

1. **TransactionManagementViewModelTests** (20 tests)

   - Init default state (no pending deletion)
   - Sorted transactions (newest first)
   - Empty transaction list
   - Transaction count
   - canDelete validation (sell/transferOut always safe, buy safe when quantity >= 0, buy unsafe when negative)
   - Initiate delete (safe → confirmation, unsafe → error)
   - Confirm delete (removes transaction, resets state, updates asset quantity)
   - Cancel delete (resets all state, preserves transactions)
   - Field preservation across sorting
   - Multiple transaction types ordering
   - Same-date transaction handling

### Service Tests

1. **ExchangeRateServiceTests**
   - Same-currency no-op (base and non-base)
   - Direct conversion from base currency
   - Inverse conversion to base currency
   - Cross-currency conversion via base
   - Missing rate handling (source, target, both)
   - Edge cases (zero amount, empty rates, zero rate)

### Integration Tests

1. **AssetIntegrationTests**
   - Asset saved to SwiftData with initial transaction
   - Asset-Portfolio relationship bidirectional linkage
   - Multiple assets in same portfolio
   - Price history creation
   - Asset editing updates properties correctly
   - Portfolio total value reflects new assets
   - Portfolio asset count updates
   - Asset quantity calculation from transactions
   - Asset current value calculation

______________________________________________________________________
