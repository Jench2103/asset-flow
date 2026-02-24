# AssetFlow Tests

## Framework

Uses **Swift Testing** (`import Testing`), NOT XCTest. No `XCTAssert*` or `XCTestCase`. See `Documentation/TestingStrategy.md` for coverage goals.

## Test-Driven Development (TDD)

Red-Green-Refactor: write a failing test first, implement minimum code to pass, then refactor. Services are stateless — test with pure input/output.

## Structure

```swift
import Foundation
import SwiftData
import Testing

@testable import AssetFlow

@Suite("ComponentName Tests")
@MainActor
struct ComponentNameTests {

  @Test("Description of what is tested")
  func testDescriptiveName() {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    // Arrange → Act → Assert
    #expect(result == expected)
  }
}
```

## Key Rules

1. Tests are `struct`, annotated with `@Suite("Name")` and `@MainActor` — even for pure-logic tests (ensures consistency and avoids issues if SwiftData dependencies are added later)
1. `@Test("Human-readable description")` on each test method
1. `#expect(...)` for assertions, `#require(...)` for preconditions
1. Each test creates its own in-memory container — no shared state
1. Use private helpers inside the test struct for reusable setup

## SwiftData Lifetime (Critical)

`ModelContainer` must be retained for the entire test scope. ARC can deallocate it early even if `ModelContext` holds a back-reference, destroying the backing store. Accessing `@Relationship` properties then crashes with SIGTRAP: "This model instance was destroyed by calling ModelContext.reset". All tests in the suite report "failed" at 0.000s.

**`_` does NOT retain** — `let (_, context) = helper()` discards immediately. Use the `TestContext` pattern:

```swift
private struct TestContext {
    let container: ModelContainer
    let context: ModelContext
    let snapshot: Snapshot
}

// Usage — container stays alive through `tc`
let tc = createSnapshotWithContext()
let (context, snapshot) = (tc.context, tc.snapshot)
```

## Debugging Crashes

- Capture output once: `xcodebuild ... test > /tmp/test-output.txt 2>&1`
- Use `-parallel-testing-enabled NO` and `-only-testing:AssetFlowTests/SuiteName` to isolate
- Use `-maximum-test-execution-time-allowance 10` to prevent crash/retry cycles from running forever
- When one test crashes (SIGTRAP), the entire process dies and all tests report "failed" at 0.000s — only one pattern is at fault
- Use `xcrun xcresulttool get test-results summary --path <.xcresult>` for structured JSON output

## File Naming

`[Component]Tests.swift` — e.g., `AssetFormViewModelTests.swift`
