# Testing Strategy

## Overview

This document outlines the testing strategy for AssetFlow, covering unit testing, integration testing, UI testing, and manual testing approaches for a SwiftUI + SwiftData application.

**Current Status**: Testing infrastructure is planned but not yet implemented. This document serves as a blueprint for future development.

______________________________________________________________________

## Testing Philosophy

### Core Principles

1. **Test-Driven Development (TDD)**: Write tests before or alongside implementation when practical
1. **Pyramid Structure**: More unit tests, fewer integration tests, minimal UI tests
1. **Fast Feedback**: Tests should run quickly and provide clear failure messages
1. **Isolation**: Tests should not depend on each other or external state
1. **Maintainability**: Tests are code too—keep them clean and well-organized
1. **Coverage**: Aim for high coverage on business logic, moderate on UI

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

**Target Distribution**:

- **70%** Unit Tests
- **20%** Integration Tests
- **10%** UI/E2E Tests

______________________________________________________________________

## Testing Framework

### Primary Framework: Swift Testing (Recommended)

**Why Swift Testing**:

- Modern, Swift-native testing framework
- Better SwiftUI/SwiftData integration
- Cleaner syntax with macros
- Improved async/await support
- Built-in parameterized testing

**Alternative**: XCTest (traditional, well-established)

### Setup

Add Swift Testing to your project:

```swift
// In Xcode: File → Add Package Dependencies
// URL: https://github.com/apple/swift-testing
```

**Test Target Structure**:

```
AssetFlowTests/
├── UnitTests/
│   ├── Models/
│   ├── ViewModels/
│   └── Services/
├── IntegrationTests/
│   └── SwiftData/
├── UITests/
│   └── Flows/
└── Helpers/
    └── TestUtilities.swift
```

______________________________________________________________________

## Unit Testing

### What to Test

**Models**:

- Initialization
- **Computed properties** (this is critical, as most state is computed)
- Validation logic
- Business rules
- Decimal calculations (financial precision)

**ViewModels**:

- State changes
- Business logic
- Data transformations
- Error handling
- Async operations

**Services**:

- Data operations
- API interactions (mocked)
- Error scenarios
- Edge cases

### Example: Model Testing (Computed Properties)

Testing a model like `Asset` now requires setting up its dependencies (`Transaction` and `PriceHistory`) to test its computed properties.

```swift
import Testing
import Foundation
@testable import AssetFlow

@Test("Asset computes quantity correctly from transactions")
func assetComputesQuantity() {
    // Arrange
    let asset = Asset(name: "Test Stock", assetType: .stock, currency: "USD")

    let t1 = Transaction(transactionType: .buy, transactionDate: Date(), quantity: 10, pricePerUnit: 100, asset: asset)
    let t2 = Transaction(transactionType: .buy, transactionDate: Date(), quantity: 5, pricePerUnit: 110, asset: asset)
    let t3 = Transaction(transactionType: .sell, transactionDate: Date(), quantity: 8, pricePerUnit: 120, asset: asset)

    asset.transactions = [t1, t2, t3]

    // Act
    let currentQuantity = asset.quantity

    // Assert
    #expect(currentQuantity == 7) // 10 + 5 - 8 = 7
}

@Test("Asset computes currentValue from quantity and latest price")
func assetComputesValue() {
    // Arrange
    let asset = Asset(name: "Test Stock", assetType: .stock, currency: "USD")

    // Transactions to establish quantity
    let t1 = Transaction(transactionType: .buy, transactionDate: Date(), quantity: 10, pricePerUnit: 100, asset: asset)
    asset.transactions = [t1]

    // Price history
    let p1 = PriceHistory(date: Date().addingTimeInterval(-100), price: 100, asset: asset)
    let p2 = PriceHistory(date: Date(), price: 125, asset: asset) // Latest price
    asset.priceHistory = [p1, p2]

    // Act
    let currentValue = asset.currentValue

    // Assert
    #expect(currentValue == 1250) // 10 shares * $125/share
}

@Test("Asset computes average cost correctly")
func assetComputesAverageCost() {
    // Arrange
    let asset = Asset(name: "Test Stock", assetType: .stock, currency: "USD")

    let t1 = Transaction(transactionType: .buy, transactionDate: Date(), quantity: 10, pricePerUnit: 100, totalAmount: 1000, asset: asset)
    let t2 = Transaction(transactionType: .buy, transactionDate: Date(), quantity: 10, pricePerUnit: 120, totalAmount: 1200, asset: asset)
    asset.transactions = [t1, t2]

    // Act
    let averageCost = asset.averageCost

    // Assert
    #expect(averageCost == 110) // ($1000 + $1200) / (10 + 10) = $110
}
```

### Example: ViewModel Testing

```swift
import Testing
import Foundation
@testable import AssetFlow

@MainActor
@Test("PortfolioViewModel loads portfolios")
func portfolioViewModelLoadsData() async {
    // Arrange
    let mockService = MockDataService()
    let viewModel = PortfolioViewModel(dataService: mockService)

    // Act
    await viewModel.loadPortfolios()

    // Assert
    #expect(viewModel.portfolios.count > 0)
    #expect(viewModel.isLoading == false)
}

@MainActor
@Test("PortfolioViewModel handles errors")
func portfolioViewModelHandlesErrors() async {
    // Arrange
    let mockService = MockDataService(shouldFail: true)
    let viewModel = PortfolioViewModel(dataService: mockService)

    // Act
    await viewModel.loadPortfolios()

    // Assert
    #expect(viewModel.error != nil)
    #expect(viewModel.portfolios.isEmpty)
}
```

______________________________________________________________________

## Integration Testing

### What to Test

**SwiftData Integration**:

- CRUD operations
- Relationships (cascade, nullify, etc.)
- Queries with predicates
- Transaction rollback
- Schema migrations (future)

**Service Integration**:

- ViewModel + Service interaction
- Data flow between layers
- State synchronization

### SwiftData Testing

**Setup**: Use in-memory container for tests

```swift
import Testing
import SwiftData
@testable import AssetFlow

struct SwiftDataTestContainer {
    let container: ModelContainer

    init() {
        let schema = Schema([
            Asset.self,
            Portfolio.self,
            Transaction.self,
            PriceHistory.self,
            InvestmentPlan.self
        ])

        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true  // ← In-memory for tests
        )

        container = try! ModelContainer(
            for: schema,
            configurations: [configuration]
        )
    }
}
```

**Example Test**:

```swift
@Test("Deleting asset cascades to transactions and price history")
func deleteAssetCascades() async throws {
    // Arrange
    let testContainer = SwiftDataTestContainer()
    let context = ModelContext(testContainer.container)

    let asset = Asset(name: "Test", assetType: .stock, currency: "USD")
    let transaction = Transaction(transactionType: .buy, transactionDate: Date(), quantity: 1, pricePerUnit: 100, asset: asset)
    let price = PriceHistory(date: Date(), price: 100, asset: asset)

    context.insert(asset)
    context.insert(transaction)
    context.insert(price)
    try context.save()

    // Act
    context.delete(asset)
    try context.save()

    // Assert
    let tDescriptor = FetchDescriptor<Transaction>()
    let pDescriptor = FetchDescriptor<PriceHistory>()
    #expect(try context.fetch(tDescriptor).isEmpty)
    #expect(try context.fetch(pDescriptor).isEmpty)
}
```

______________________________________________________________________

## UI Testing

### What to Test

**Critical User Flows**:

- Portfolio creation and management
- Asset addition and editing
- Transaction recording
- Navigation flows
- Data persistence across app launches

**Accessibility**:

- VoiceOver support
- Dynamic Type scaling
- Keyboard navigation (macOS)

### SwiftUI Testing Approaches

**Preview Testing** (Manual):

```swift
#Preview("Portfolio List - Empty") {
    PortfolioListView()
        .modelContainer(previewContainer)
}

#Preview("Portfolio List - Populated") {
    PortfolioListView()
        .modelContainer(previewContainerWithData)
}
```

**UI Tests** (Automated):

```swift
import XCTest

final class PortfolioFlowUITests: XCTestCase {
    var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launchArguments = ["UI-Testing"]  // Configure for testing
        app.launch()
    }

    func testCreateNewPortfolio() {
        // Tap "New Portfolio" button
        app.buttons["NewPortfolioButton"].tap()

        // Enter portfolio name
        let nameField = app.textFields["PortfolioNameField"]
        nameField.tap()
        nameField.typeText("Test Portfolio")

        // Save
        app.buttons["SaveButton"].tap()

        // Verify portfolio appears in list
        XCTAssertTrue(app.staticTexts["Test Portfolio"].exists)
    }
}
```

______________________________________________________________________

## Mocking and Test Doubles

### Mock Data Services

```swift
protocol DataService {
    func fetchPortfolios() async throws -> [Portfolio]
    func save(_ portfolio: Portfolio) async throws
}

class MockDataService: DataService {
    var shouldFail = false
    var mockPortfolios: [Portfolio] = []

    func fetchPortfolios() async throws -> [Portfolio] {
        if shouldFail {
            throw DataError.fetchFailed
        }
        return mockPortfolios
    }

    func save(_ portfolio: Portfolio) async throws {
        if shouldFail {
            throw DataError.saveFailed
        }
        mockPortfolios.append(portfolio)
    }
}
```

### Test Fixtures

```swift
extension Portfolio {
    static var testPortfolio: Portfolio {
        Portfolio(
            name: "Test Portfolio",
            createdDate: Date(),
            isActive: true
        )
    }
}

extension Asset {
    static var testAsset: Asset {
        Asset(name: "Test Asset", assetType: .stock, currency: "USD")
    }
}
```

______________________________________________________________________

## Snapshot Testing (Optional)

### Visual Regression Testing

Use **swift-snapshot-testing** for UI consistency:

```swift
import SnapshotTesting
import SwiftUI

@Test("PortfolioCard renders correctly")
func portfolioCardSnapshot() {
    let portfolio = Portfolio.testPortfolio
    let view = PortfolioCard(portfolio: portfolio)

    assertSnapshot(matching: view, as: .image)
}
```

______________________________________________________________________

## Performance Testing

### Measure Performance

```swift
@Test(.timeLimit(.minutes(1)))
func portfolioCalculationPerformance() async {
    let portfolio = Portfolio.testPortfolio

    // Add many assets
    for i in 0..<1000 {
        let asset = Asset(name: "Asset \(i)", assetType: .stock, currency: "USD")
        portfolio.assets?.append(asset)
    }

    // Measure
    let startTime = Date()
    _ = portfolio.totalValue
    let duration = Date().timeIntervalSince(startTime)

    #expect(duration < 0.1)  // Should complete in <100ms
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

### Enable Coverage in Xcode

1. Edit Scheme → Test
1. Options → Code Coverage → ✓ Gather coverage for some targets
1. Select AssetFlow target
1. Run tests
1. View coverage: Report Navigator → Coverage tab

### Command Line Coverage

```bash
xcodebuild test \
  -project AssetFlow.xcodeproj \
  -scheme AssetFlow \
  -enableCodeCoverage YES \
  -resultBundlePath TestResults.xcresult
```

______________________________________________________________________

## Continuous Integration

### GitHub Actions (Planned)

```yaml
name: Tests
on: [push, pull_request]

jobs:
  test:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3

      - name: Select Xcode
        run: sudo xcode-select -s /Applications/Xcode_15.0.app

      - name: Run Unit Tests
        run: |
          xcodebuild test \
            -project AssetFlow.xcodeproj \
            -scheme AssetFlow \
            -destination 'platform=macOS' \
            -enableCodeCoverage YES

      - name: Run iOS Tests
        run: |
          xcodebuild test \
            -project AssetFlow.xcodeproj \
            -scheme AssetFlow \
            -destination 'platform=iOS Simulator,name=iPhone 15 Pro' \
            -enableCodeCoverage YES

      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          files: ./coverage.xml
```

______________________________________________________________________

## Manual Testing

### Testing Checklist

**Before Each Release**:

#### Functional Testing

- [ ] Create, edit, delete portfolios
- [ ] Add, update, remove assets
- [ ] Record transactions (all types)
- [ ] Verify financial calculations (totals, gains/losses)
- [ ] Test target allocation tracking
- [ ] Investment plan CRUD operations

#### Data Persistence

- [ ] Data survives app restart
- [ ] Relationships maintained after save/load
- [ ] No data loss on background/foreground

#### Platform Testing

**macOS**:

- [ ] Window resizing
- [ ] Keyboard shortcuts
- [ ] Menu bar items
- [ ] Multi-window support (future)

**iOS**:

- [ ] Portrait/landscape orientation
- [ ] Safe area handling
- [ ] Keyboard avoidance
- [ ] Pull-to-refresh

**iPadOS**:

- [ ] Split view
- [ ] Drag and drop (future)
- [ ] Keyboard shortcuts
- [ ] Pointer support

#### Edge Cases

- [ ] Empty states (no portfolios, no assets)
- [ ] Large datasets (100+ assets)
- [ ] Very long asset names
- [ ] Zero/negative values
- [ ] Future/past dates
- [ ] Decimal precision (9+ decimal places)

#### Accessibility

- [ ] VoiceOver navigation
- [ ] Dynamic Type scaling (Smallest to Largest)
- [ ] Reduce Motion support
- [ ] High Contrast mode
- [ ] Keyboard-only navigation (macOS)

______________________________________________________________________

## Test Data Management

### Development Data

**Create Test Data Helper**:

```swift
struct TestDataGenerator {
    static func generatePortfolio(assetCount: Int = 5) -> Portfolio {
        let portfolio = Portfolio(
            name: "Generated Portfolio",
            createdDate: Date(),
            isActive: true
        )

        for i in 0..<assetCount {
            let asset = Asset(name: "Asset \(i)", assetType: .stock, currency: "USD")
            asset.portfolio = portfolio
        }

        return portfolio
    }
}
```

**Preview Container with Data**:

```swift
@MainActor
let previewContainerWithData: ModelContainer = {
    let schema = Schema([Portfolio.self, Asset.self, Transaction.self, PriceHistory.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )

    let context = container.mainContext

    // Generate test data
    for i in 1...3 {
        let portfolio = TestDataGenerator.generatePortfolio(assetCount: 5)
        context.insert(portfolio)
    }

    return container
}()
```

______________________________________________________________________

## Debugging Tests

### Test Failure Strategies

1. **Read the failure message carefully**
1. **Check test data and setup**
1. **Add breakpoints in test**
1. **Print intermediate values** (in tests, `print()` is OK)
1. **Isolate the failing code**
1. **Simplify the test**

### Xcode Test Debugging

- Set breakpoints in tests
- Run single test: Click diamond in gutter
- Test navigator: `⌘6` → Right-click → Debug Test
- View test logs: Report Navigator → Test

### Common Test Issues

**Async/await timing**:

```swift
// Bad: Doesn't wait for async
@Test func testAsync() {
    viewModel.loadData()
    #expect(viewModel.data.count > 0)  // ❌ Might not be loaded yet
}

// Good: Properly awaits
@Test func testAsync() async {
    await viewModel.loadData()
    #expect(viewModel.data.count > 0)  // ✅ Data loaded
}
```

**SwiftData context issues**:

```swift
// Ensure context is saved
try context.save()

// Ensure fetching from same context
let descriptor = FetchDescriptor<Portfolio>()
let results = try context.fetch(descriptor)
```

______________________________________________________________________

## Best Practices

### General Guidelines

1. **Test behavior, not implementation**
1. **One assertion per test** (when practical)
1. **Descriptive test names** (`testWhat_When_Then` format)
1. **Arrange-Act-Assert** pattern
1. **Independent tests** (no shared state)
1. **Fast tests** (< 100ms for unit tests)
1. **Avoid testing framework code** (SwiftUI, SwiftData internals)
1. **Test edge cases** (nil, empty, large values)

### What NOT to Test

- SwiftUI framework behavior
- SwiftData persistence mechanics
- Third-party library internals
- Trivial getters/setters
- Auto-generated code

### When to Write Tests

- **Before coding** (TDD approach)
- **While coding** (verify as you build)
- **After coding** (cover edge cases)
- **When fixing bugs** (regression tests)

______________________________________________________________________

## Future Enhancements

### Planned Testing Features

1. **Automated UI testing** in CI/CD
1. **Snapshot testing** for consistent UI
1. **Performance benchmarking** suite
1. **Accessibility auditing** tools
1. **Load testing** for large datasets
1. **Security testing** for data protection
1. **Multi-platform test coverage** reports

______________________________________________________________________

## Resources

### Documentation

- [Swift Testing Guide](https://developer.apple.com/documentation/testing)
- [XCTest Documentation](https://developer.apple.com/documentation/xctest)
- [SwiftData Testing](https://developer.apple.com/documentation/swiftdata)

### Tools

- [swift-testing](https://github.com/apple/swift-testing)
- [swift-snapshot-testing](https://github.com/pointfreeco/swift-snapshot-testing)

### Best Practices

- [Testing Tips](https://www.swiftbysundell.com/basics/unit-testing/)
- [TDD in Swift](https://www.vadimbulavin.com/tdd-in-swift/)

______________________________________________________________________

## Summary

This testing strategy provides a comprehensive framework for ensuring AssetFlow's quality, reliability, and maintainability. Implement tests incrementally, focusing on critical business logic first, then expanding coverage over time.

**Next Steps**:

1. Set up test targets in Xcode
1. Add Swift Testing dependency
1. Create test helpers and fixtures
1. Write tests for existing models
1. Implement ViewModel tests as ViewModels are created
1. Integrate testing into CI/CD pipeline
