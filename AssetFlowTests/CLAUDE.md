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
1. Annotate with `@Suite("Name")` and `@MainActor` — even for pure-logic tests (e.g., stateless services). This ensures consistency across the test suite and avoids issues if SwiftData dependencies are added later.
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

## SwiftData Lifetime

**Critical:** `ModelContainer` must be retained for the entire test scope. If a helper creates a container, the caller must hold a strong reference to it. ARC can deallocate the container early — even if `ModelContext` has a back-reference — destroying the backing store and crashing on any `@Relationship` property access.

**`_` does NOT retain values.** `let (_, context, snapshot) = helper()` discards the first element immediately. Always use a named binding.

Use a `TestContext` struct to bundle container + context + model objects. This retains the container and eliminates "unused variable" warnings:

```swift
private struct TestContext {
    let container: ModelContainer
    let context: ModelContext
    let snapshot: Snapshot
}

private func createSnapshotWithContext() -> TestContext {
    let container = TestDataManager.createInMemoryContainer()
    let context = container.mainContext
    let snapshot = Snapshot(date: ...)
    context.insert(snapshot)
    return TestContext(container: container, context: context, snapshot: snapshot)
}

// Usage — container stays alive through `tc` for the entire test scope
let tc = createSnapshotWithContext()
let (context, snapshot) = (tc.context, tc.snapshot)
```

## Debugging Test Crashes

**Avoid repeated test runs:**

1. Capture full output to a file once, then read from it — never re-run the build just to grep for different patterns:
   ```bash
   xcodebuild ... test ... > /tmp/test-output.txt 2>&1; echo "EXIT: $?"
   ```
1. Use `-maximum-test-execution-time-allowance 10` to prevent crash/retry cycles from running forever

**Isolate the crash:**

1. Use `-parallel-testing-enabled NO` to see sequential execution and identify exactly which test crashes
1. Use `-only-testing:AssetFlowTests/SuiteName` to isolate a specific suite
1. Run a known-passing suite (e.g., one without SwiftData) to confirm the crash is domain-specific

**Understand crash cascade:**

When one Swift Testing test crashes (SIGTRAP), the **entire test process** dies and ALL tests in the suite are reported as "failed" at 0.000 seconds — even tests that never ran. The runner retries with a new process, which crashes on the next problematic test. This makes it look like every test is broken when only one pattern is at fault.

**Use xcresulttool for structured output:**

```bash
xcrun xcresulttool get test-results summary --path <path-to.xcresult>
```

Returns JSON with clear `"failureText": "Test crashed with signal trap"`.

## Common Errors

### "This model instance was destroyed by calling ModelContext.reset"

**Symptoms:** SIGTRAP crash, all tests in the suite fail at 0.000 seconds, breakpoint lands past the end of a model source file (in `@Model` macro-synthesized relationship getter).

**Root cause:** `ModelContainer` was deallocated before the test finished. When the container is freed, the backing store is destroyed and the internal context is reset. Any subsequent access to `@Relationship` properties triggers the fatal error.

**Fix:** Ensure every test retains the `ModelContainer` for its full scope. Use the `TestContext` struct pattern described above.

## File Naming

`[Component]Tests.swift` — e.g., `AssetFormViewModelTests.swift`, `PortfolioModelTests.swift`
