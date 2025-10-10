# Code Style Guide

## Overview

This document defines the code style standards for the AssetFlow project. Consistency in code style improves readability, maintainability, and collaboration.

## Enforcement

Code style is enforced through:

- **swift-format**: Automated formatting (`.swift-format` config)
- **SwiftLint**: Style and convention linting (`.swiftlint.yml` config)
- **EditorConfig**: Editor settings (`.editorconfig`)
- **Pre-commit hooks**: Automated checks before commits (`.pre-commit-config.yaml`)

______________________________________________________________________

## General Principles

1. **Clarity over brevity**: Code should be self-documenting
1. **Consistency**: Follow established patterns in the codebase
1. **Swift API Design Guidelines**: Follow Apple's official guidelines
1. **Type safety**: Leverage Swift's type system
1. **Immutability**: Prefer `let` over `var` when possible

______________________________________________________________________

## File Organization

### File Structure

```swift
//
//  FileName.swift
//  AssetFlow
//
//  Created by [Name] on YYYY/MM/DD.
//

// 1. Imports (sorted alphabetically)
import Foundation
import SwiftData
import SwiftUI

// 2. Type definitions
// 3. Extensions
// 4. Helper types (if small and related)
```

### Import Organization

**Order**:

1. System frameworks (alphabetically)
1. Third-party dependencies (alphabetically)
1. Internal modules (alphabetically)

**Example**:

```swift
import Foundation
import SwiftData
import SwiftUI
```

**SwiftLint Rule**: Imports must be sorted alphabetically.

______________________________________________________________________

## Naming Conventions

### Types

**Classes, Structs, Enums, Protocols**: `UpperCamelCase`

```swift
class PortfolioViewModel { }
struct Asset { }
enum TransactionType { }
protocol DataService { }
```

### Variables and Functions

**Variables, Constants, Functions**: `lowerCamelCase`

```swift
var currentValue: Decimal
let purchaseDate: Date
func calculateGainLoss() -> Decimal
```

### Acronyms

Treat acronyms as words:

```swift
// Good
let urlString: String
let apiKey: String
class HttpClient { }

// Bad
let uRLString: String
let aPIKey: String
class HTTPClient { }
```

### Boolean Properties

Use `is`, `has`, `should`, or `can` prefixes:

```swift
var isActive: Bool
var hasTransactions: Bool
var shouldRefresh: Bool
var canEdit: Bool
```

### Protocols

**Capability protocols**: `-able` suffix

```swift
protocol Comparable { }
protocol Equatable { }
```

**Data source/delegate**: `-DataSource`, `-Delegate`

```swift
protocol TableViewDataSource { }
protocol NetworkDelegate { }
```

______________________________________________________________________

## Code Formatting

### Line Length

- **Warning**: 120 characters
- **Error**: 150 characters

**Configuration**: `.swiftlint.yml`

### Indentation

- **4 spaces** (no tabs)
- **Configuration**: `.editorconfig`, `.swift-format`

### Braces

Opening brace on same line, closing brace on new line:

```swift
// Good
if condition {
    // code
}

// Bad
if condition
{
    // code
}
```

### Spacing

**Operators**:

```swift
// Good
let sum = a + b
let range = 0...10

// Bad
let sum=a+b
let range = 0 ... 10
```

**Colons**:

```swift
// Good
let dict: [String: Int] = [:]
func foo(param: String) { }

// Bad
let dict : [String : Int] = [:]
func foo(param : String) { }
```

**Commas**:

```swift
// Good
let array = [1, 2, 3]
func foo(a: Int, b: String) { }

// Bad
let array = [1,2,3]
func foo(a: Int,b: String) { }
```

### Blank Lines

- One blank line between functions
- One blank line between types
- No blank line at start/end of braces
- Two blank lines between major sections (optional)

```swift
struct Example {
    var property: String

    func methodOne() {
        // implementation
    }

    func methodTwo() {
        // implementation
    }
}
```

______________________________________________________________________

## Type Declarations

### Classes and Structs

**Use structs by default**, classes when needed for:

- Reference semantics
- Inheritance
- Deinitializers
- Objective-C interoperability

```swift
// Default: struct
struct Portfolio {
    let name: String
    var assets: [Asset]
}

// When needed: class
@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var portfolios: [Portfolio] = []
}
```

### Properties

**Computed properties** when appropriate:

```swift
// Example of a computed property on the Asset model
// (See DataModel.md for the full list)

// The most recent price from price history
var currentPrice: Decimal {
    priceHistory?.sorted(by: { $0.date > $1.date }).first?.price ?? 0
}
```

**Property observers**:

```swift
var name: String {
    didSet {
        print("Asset name changed to \(name) from \(oldValue)")
    }
}
```

### Type Inference

Use type inference when obvious:

```swift
// Good
let name = "Portfolio"
let count = 5
let items: [Asset] = []  // Explicit when empty

// Avoid
let name: String = "Portfolio"
let count: Int = 5
```

______________________________________________________________________

## Functions

### Declaration

```swift
func functionName(parameterLabel argumentName: Type) -> ReturnType {
    // implementation
}
```

### Parameter Labels

**Use descriptive labels**:

```swift
// Good
func add(_ asset: Asset, to portfolio: Portfolio)
func calculate(gainLoss for: Asset) -> Decimal

// Bad
func add(_ asset: Asset, _ portfolio: Portfolio)
func calculate(_ asset: Asset) -> Decimal
```

**Omit label with `_`** when clear:

```swift
func print(_ value: String)
func insert(_ asset: Asset)
```

### Multiple Parameters

**Line breaks** for readability (>3 parameters or long):

```swift
// Short
func create(name: String, value: Decimal, date: Date)

// Long - break lines
func createTransaction(
    type: TransactionType,
    date: Date,
    quantity: Decimal,
    pricePerUnit: Decimal,
    totalAmount: Decimal,
    currency: String,
    fees: Decimal?
) -> Transaction
```

### Default Parameters

Place at the end:

```swift
func fetchAssets(
    for portfolio: Portfolio,
    includeInactive: Bool = false
) -> [Asset]
```

### Function Length

- **Warning**: 60 lines
- **Error**: 100 lines
- **Best practice**: Extract into smaller functions

______________________________________________________________________

## Control Flow

### if Statements

```swift
// Good
if condition {
    // code
} else if otherCondition {
    // code
} else {
    // code
}

// Multiple conditions
if condition1,
   condition2,
   condition3
{
    // code
}
```

### guard Statements

**Early exit pattern**:

```swift
func process(asset: Asset?) {
    guard let asset = asset else {
        return
    }

    // Continue with unwrapped asset
}
```

**Multiple conditions**:

```swift
guard let asset = asset,
      asset.currentValue > 0,
      let portfolio = asset.portfolio
else {
    return
}
```

### switch Statements

**Exhaustive switching**:

```swift
switch assetType {
case .stock:
    // handle stock
case .bond:
    // handle bond
case .crypto:
    // handle crypto
default:
    // handle others
}
```

**Prefer switch over if-else chains**:

```swift
// Good
switch riskLevel {
case .veryLow: return "Conservative"
case .low: return "Low Risk"
case .moderate: return "Balanced"
case .high: return "High Risk"
case .veryHigh: return "Aggressive"
}

// Avoid
if riskLevel == .veryLow {
    return "Conservative"
} else if riskLevel == .low {
    return "Low Risk"
}
// etc...
```

### for Loops

```swift
// Good
for asset in assets {
    process(asset)
}

for (index, asset) in assets.enumerated() {
    print("\(index): \(asset.name)")
}

// Use where clause for filtering
for asset in assets where asset.isActive {
    process(asset)
}
```

______________________________________________________________________

## Optionals

### Unwrapping

**Prefer optional binding**:

```swift
// Good
if let portfolio = portfolio {
    print(portfolio.name)
}

guard let portfolio = portfolio else {
    return
}
```

**Avoid force unwrapping** (generates SwiftLint warning):

```swift
// Bad (unless absolutely certain)
let portfolio = maybePortfolio!

// Exception: IBOutlets, well-documented invariants
@IBOutlet weak var tableView: UITableView!
```

### Optional Chaining

```swift
let totalValue = portfolio?.totalValue ?? 0
let firstAsset = portfolio?.assets?.first
```

### Nil Coalescing

```swift
let currency = asset.currency ?? "USD"
let fees = transaction.fees ?? 0
```

______________________________________________________________________

## SwiftUI-Specific

### View Structure

```swift
struct PortfolioView: View {
    // 1. Property wrappers
    @StateObject private var viewModel: PortfolioViewModel
    @State private var showingDetail = false

    // 2. Body
    var body: some View {
        content
    }

    // 3. Extracted view builders
    private var content: some View {
        VStack {
            // view content
        }
    }
}
```

### ViewBuilder

**Extract complex views**:

```swift
// Instead of:
var body: some View {
    VStack {
        // 50 lines of view code
    }
}

// Do:
var body: some View {
    content
}

private var content: some View {
    VStack {
        header
        mainContent
        footer
    }
}

private var header: some View {
    // header views
}
```

### Modifiers

**Order of modifiers** (generally):

1. Layout modifiers (frame, padding)
1. Style modifiers (foregroundColor, font)
1. Behavior modifiers (onTapGesture, task)

```swift
Text("Portfolio")
    .font(.headline)
    .foregroundColor(.primary)
    .padding()
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
    .onTapGesture {
        // action
    }
```

### Property Wrappers

**Order**:

```swift
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var assets: [Asset]
    @StateObject private var viewModel: ViewModel
    @State private var isPresented = false
    @Binding var selectedAsset: Asset?

    // ...
}
```

______________________________________________________________________

## SwiftData-Specific

### Model Definition

```swift
import SwiftData
import Foundation

@Model
final class Asset {
    // 1. Stored Properties (identifiers and user content)
    var id: UUID
    var name: String
    var assetType: AssetType
    var currency: String
    var notes: String?

    // 2. Relationships
    @Relationship(deleteRule: .nullify, inverse: \Portfolio.assets)
    var portfolio: Portfolio?

    @Relationship(deleteRule: .cascade, inverse: \Transaction.asset)
    var transactions: [Transaction]?

    @Relationship(deleteRule: .cascade, inverse: \PriceHistory.asset)
    var priceHistory: [PriceHistory]?

    // 3. Initializer
    init(name: String, assetType: AssetType, currency: String) {
        self.id = UUID()
        self.name = name
        self.assetType = assetType
        self.currency = currency
    }

    // 4. Computed Properties (state is derived, not stored)
    var quantity: Decimal {
        transactions?.reduce(0) { $0 + $1.quantityImpact } ?? 0
    }
}
```

### Relationships

```swift
@Relationship(deleteRule: .cascade, inverse: \Transaction.asset)
var transactions: [Transaction]?
```

______________________________________________________________________

## Financial Data

### Critical Rule: Use Decimal

**Always use `Decimal`** for monetary values:

```swift
// Good
var currentValue: Decimal
var purchasePrice: Decimal
let total: Decimal = 100.50

// Bad - NEVER use Float/Double for money
var currentValue: Double  // ❌
var purchasePrice: Float  // ❌
```

### Currency

**Default currency**: `"USD"`

```swift
var currency: String = "USD"
```

### Formatting

Use extensions from `Utilities/Extensions.swift`:

```swift
let formatted = value.formatted(currency: "USD")  // "$1,234.56"
let percentage = ratio.formattedPercentage()      // "12.34%"
```

______________________________________________________________________

## Platform-Specific Code

### Compiler Directives

```swift
#if os(macOS)
    // macOS-specific code
    .frame(minWidth: 800, minHeight: 600)
#elseif os(iOS)
    // iOS-specific code
    .navigationBarTitleDisplayMode(.large)
#else
    // Fallback
#endif
```

### Platform Checks

```swift
// For runtime checks (rare)
#if os(macOS)
let platform = "macOS"
#elseif os(iOS)
let platform = "iOS"
#endif
```

______________________________________________________________________

## Documentation

### File Headers

**Required** (enforced by SwiftLint):

```swift
//
//  FileName.swift
//  AssetFlow
//
//  Created by Your Name on 2024/01/15.
//
```

### Inline Comments

**Document complex logic**:

```swift
// Calculate the weighted average cost basis across multiple purchases
func calculateWeightedAverage() -> Decimal {
    // implementation
}
```

**Avoid obvious comments**:

```swift
// Bad
// Set name to "Portfolio"
name = "Portfolio"

// Good - comment explains WHY
// Reset to default portfolio name for new users
name = "Portfolio"
```

### Doc Comments

**Use for public APIs**:

```swift
/// Calculates the total portfolio value including all assets.
///
/// - Returns: The sum of all asset values in the portfolio's currency.
/// - Note: Inactive assets are excluded from calculation.
func calculateTotalValue() -> Decimal {
    // implementation
}
```

______________________________________________________________________

## Error Handling

### Custom Errors

```swift
enum PortfolioError: LocalizedError {
    case invalidAllocation
    case assetNotFound(id: UUID)
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        switch self {
        case .invalidAllocation:
            return "Portfolio allocation percentages must sum to 100%"
        case .assetNotFound(let id):
            return "Asset with ID \(id) not found"
        case .saveFailed(let error):
            return "Failed to save: \(error.localizedDescription)"
        }
    }
}
```

### Throwing Functions

```swift
func validateAllocation(_ allocation: [String: Decimal]) throws {
    let sum = allocation.values.reduce(0, +)
    guard sum == 100 else {
        throw PortfolioError.invalidAllocation
    }
}
```

### Do-Catch

```swift
do {
    try validateAllocation(targetAllocation)
    // proceed
} catch let error as PortfolioError {
    // handle specific error
} catch {
    // handle general error
}
```

______________________________________________________________________

## Logging

### No print() Statements

**SwiftLint Custom Rule**: `print()` statements are **prohibited**.

### Use os.log Instead

```swift
import os.log

let logger = Logger(
    subsystem: "com.yourname.AssetFlow",
    category: "Portfolio"
)

// Log levels
logger.debug("Debug information")
logger.info("Informational message")
logger.warning("Warning occurred")
logger.error("Error: \(error.localizedDescription)")
```

______________________________________________________________________

## Testing (Future)

### Test Naming

```swift
func testPortfolioCalculatesTotalValue() {
    // test implementation
}

func testAssetValidation_WithInvalidData_ThrowsError() {
    // test implementation
}
```

### Test Structure

```swift
// Arrange
let portfolio = Portfolio(name: "Test")
let asset = Asset(name: "AAPL", value: 100)

// Act
portfolio.addAsset(asset)

// Assert
XCTAssertEqual(portfolio.totalValue, 100)
```

______________________________________________________________________

## Swift Best Practices

### Value Types vs Reference Types

**Prefer structs** (value types) for:

- Data models without inheritance
- Thread-safe data
- Functional transformations

**Use classes** (reference types) for:

- SwiftData models (`@Model` requires class)
- ViewModels (`ObservableObject` requires class)
- Shared mutable state

### Access Control

**Be explicit**:

```swift
public class PublicAPI { }
internal struct InternalData { }  // Default
private var privateState: Int
fileprivate var filePrivateHelper: String
```

**General rule**: Use most restrictive access level possible.

### Extensions

**Group related functionality**:

```swift
// MARK: - Computed Properties
extension Portfolio {
    var isBalanced: Bool {
        // check allocation
    }
}

// MARK: - Validation
extension Portfolio {
    func validate() throws {
        // validation logic
    }
}
```

### Protocol Conformance

**Use extensions**:

```swift
struct Asset {
    // main definition
}

// MARK: - Equatable
extension Asset: Equatable {
    static func == (lhs: Asset, rhs: Asset) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Comparable
extension Asset: Comparable {
    static func < (lhs: Asset, rhs: Asset) -> Bool {
        lhs.currentValue < rhs.currentValue
    }
}
```

______________________________________________________________________

## Code Review Guidelines

### What to Look For

- [ ] Follows naming conventions
- [ ] Proper use of `Decimal` for financial data
- [ ] No `print()` statements
- [ ] File headers present
- [ ] Appropriate access control
- [ ] Platform-specific code uses `#if os()`
- [ ] Optional handling is safe
- [ ] Functions are focused and short
- [ ] Comments explain "why" not "what"
- [ ] SwiftLint warnings addressed
- [ ] Formatted with swift-format

______________________________________________________________________

## Tools Configuration

### .swift-format

```json
{
  "version": 1,
  "indentation": {
    "spaces": 4
  },
  "lineLength": 100,
  "respectsExistingLineBreaks": true
}
```

### .swiftlint.yml

Key rules:

- `line_length`: warning: 120, error: 150
- `function_body_length`: warning: 60, error: 100
- `custom_rules.no_print`: Prohibit `print()`
- `sorted_imports`: Required

### .editorconfig

```ini
[*.swift]
indent_style = space
indent_size = 4
end_of_line = lf
charset = utf-8
trim_trailing_whitespace = true
insert_final_newline = true
```

______________________________________________________________________

## References

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftLint Rules](https://realm.github.io/SwiftLint/rule-directory.html)
- [swift-format](https://github.com/apple/swift-format)
- Project configurations: `.swiftlint.yml`, `.swift-format`, `.editorconfig`

______________________________________________________________________

## Questions or Clarifications?

Refer to existing code for patterns, or consult the team for ambiguous cases. When in doubt, prioritize **clarity** and **consistency** with the existing codebase.
