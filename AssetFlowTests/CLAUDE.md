# AssetFlow Tests

## Framework

This project uses **Swift Testing** (`import Testing`), NOT XCTest.

Do NOT use `XCTAssert*`, `XCTestCase`, or any XCTest APIs.

## Test Structure

```swift
import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("ComponentName Tests")
@MainActor
struct ComponentNameTests {

  @Test("Human-readable description of what is tested")
  func testDescriptiveName() {
    // Arrange
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    // ... set up test data ...

    // Act
    let result = /* operation under test */

    // Assert
    #expect(result == expectedValue)
  }
}
```

## Key Rules

1. Tests are `struct` (not `class`)
1. Annotate with `@Suite("Name")` and `@MainActor`
1. Each test method gets `@Test("Human-readable description")`
1. Use `#expect(...)` for assertions, `#require(...)` for preconditions that must pass
1. Follow AAA pattern: Arrange, Act, Assert

## Test Data

Use `TestDataManager.createInMemoryContainer()` for isolated in-memory SwiftData containers:

```swift
let container = TestDataManager.createInMemoryContainer()
let context = container.mainContext
```

Each test creates its own container — no shared state between tests.

## Helpers

Private helper functions inside the test struct for reusable setup:

```swift
@Suite("Foo Tests")
@MainActor
struct FooTests {
  private func createTestAsset(in context: ModelContext) -> Asset {
    let asset = Asset(name: "Test", type: .stock, currency: "USD")
    context.insert(asset)
    return asset
  }
}
```

## File Naming

`[Component]Tests.swift` — e.g., `AssetFormViewModelTests.swift`, `PortfolioModelTests.swift`
