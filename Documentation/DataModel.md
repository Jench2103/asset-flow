# Data Model Documentation

📋 **Looking for a quick reference?** See [AssetFlow/Models/README.md](../AssetFlow/Models/README.md) for a concise overview.

## Overview

AssetFlow uses SwiftData for type-safe, modern data persistence across macOS, iOS, and iPadOS. The data model is designed for financial precision, relationship integrity, and extensibility.

This document provides comprehensive documentation for all data models, including detailed property tables, relationships, SwiftData configuration, validation rules, and usage examples.

## Core Principles

### Financial Data Precision

- **Always use `Decimal`** for monetary values (never `Float` or `Double`)
- Prevents floating-point rounding errors in financial calculations
- Default currency: `"USD"`
- Currency-aware formatting via extensions

### Relationship Design

- Clear parent-child relationships
- Optional relationships where appropriate
- Cascade delete rules for data integrity
- Inverse relationships for bidirectional navigation

### Schema Management

- All models registered in `AssetFlowApp.swift` `sharedModelContainer`
- Schema versioning for migration support
- When adding models, update both Schema and this documentation

## Model Entities

### Asset

Represents an individual investment or asset in a portfolio.

**File**: `AssetFlow/Models/Asset.swift`

#### Properties

| Property        | Type        | Description                            | Required |
| --------------- | ----------- | -------------------------------------- | -------- |
| `id`            | `UUID`      | Unique identifier                      | ✓        |
| `name`          | `String`    | Display name (e.g., "Apple Inc.")      | ✓        |
| `assetType`     | `AssetType` | Asset category                         | ✓        |
| `currentValue`  | `Decimal`   | Current market value of total holdings | ✓        |
| `purchaseDate`  | `Date`      | Initial acquisition date               | ✓        |
| `purchasePrice` | `Decimal?`  | Original purchase price per unit       | ✗        |
| `quantity`      | `Decimal`   | Number of units held                   | ✓        |
| `currency`      | `String`    | Currency code (default: "USD")         | ✓        |
| `notes`         | `String?`   | User notes/comments                    | ✗        |
| `lastUpdated`   | `Date`      | Last update timestamp                  | ✓        |

#### Relationships

```swift
@Relationship(deleteRule: .nullify, inverse: \Portfolio.assets)
var portfolio: Portfolio?

@Relationship(deleteRule: .cascade, inverse: \Transaction.asset)
var transactions: [Transaction]?
```

- **Portfolio**: Optional parent (`.nullify` on delete)
- **Transactions**: Child records (`.cascade` on delete)

#### Asset Types

```swift
enum AssetType: String, Codable {
    case stock          // Publicly traded stocks
    case bond           // Government or corporate bonds
    case crypto         // Cryptocurrencies
    case realEstate     // Real estate properties
    case commodity      // Gold, silver, oil, etc.
    case cash           // Cash holdings and savings
    case mutualFund     // Mutual fund investments
    case etf            // Exchange-traded funds
    case other          // Other asset types
}
```

#### Computed Properties

```swift
// Total cost basis
var totalCost: Decimal {
    (purchasePrice ?? 0) * quantity
}

// Gain/loss calculation
var gainLoss: Decimal {
    currentValue - totalCost
}

// Percentage return
var returnPercentage: Decimal {
    totalCost > 0 ? (gainLoss / totalCost) * 100 : 0
}
```

#### Usage Example

```swift
let asset = Asset(
    name: "Apple Inc.",
    assetType: .stock,
    currentValue: 15000.00,
    purchaseDate: Date(),
    purchasePrice: 150.00,
    quantity: 100,
    currency: "USD"
)
```

______________________________________________________________________

### Portfolio

Represents a collection of assets grouped for organizational or strategic purposes.

**File**: `AssetFlow/Models/Portfolio.swift`

#### Properties

| Property               | Type                 | Description            | Required |
| ---------------------- | -------------------- | ---------------------- | -------- |
| `id`                   | `UUID`               | Unique identifier      | ✓        |
| `name`                 | `String`             | Display name           | ✓        |
| `portfolioDescription` | `String?`            | Detailed description   | ✗        |
| `createdDate`          | `Date`               | Creation timestamp     | ✓        |
| `targetAllocation`     | `[String: Decimal]?` | Target % by asset type | ✗        |
| `isActive`             | `Bool`               | Active status          | ✓        |

#### Relationships

```swift
@Relationship(deleteRule: .nullify, inverse: \Asset.portfolio)
var assets: [Asset]?
```

- **Assets**: Child assets (`.nullify` on delete - assets persist independently)

#### Target Allocation

Dictionary mapping asset type to percentage:

```swift
[
    "Stock": 60.0,
    "Bond": 30.0,
    "Cash": 10.0
]
```

#### Computed Properties

```swift
// Sum of all asset values
var totalValue: Decimal {
    assets?.reduce(0) { $0 + $1.currentValue } ?? 0
}

// Current allocation percentages
var currentAllocation: [String: Decimal] {
    // Calculate actual allocation by asset type
}

// Allocation drift from target
var allocationDrift: [String: Decimal] {
    // Compare current vs target allocation
}
```

#### Usage Example

```swift
let portfolio = Portfolio(
    name: "Retirement Portfolio",
    portfolioDescription: "Long-term retirement savings",
    createdDate: Date(),
    targetAllocation: [
        "Stock": 60.0,
        "Bond": 30.0,
        "Cash": 10.0
    ],
    isActive: true
)
```

______________________________________________________________________

### Transaction

Represents a single financial transaction related to an asset.

**File**: `AssetFlow/Models/Transaction.swift`

#### Properties

| Property          | Type              | Description             | Required |
| ----------------- | ----------------- | ----------------------- | -------- |
| `id`              | `UUID`            | Unique identifier       | ✓        |
| `transactionType` | `TransactionType` | Transaction category    | ✓        |
| `transactionDate` | `Date`            | When it occurred        | ✓        |
| `quantity`        | `Decimal`         | Units involved          | ✓        |
| `pricePerUnit`    | `Decimal`         | Unit price              | ✓        |
| `totalAmount`     | `Decimal`         | Total transaction value | ✓        |
| `currency`        | `String`          | Currency code           | ✓        |
| `fees`            | `Decimal?`        | Transaction fees        | ✗        |
| `notes`           | `String?`         | Additional notes        | ✗        |

#### Relationships

```swift
@Relationship(deleteRule: .nullify, inverse: \Asset.transactions)
var asset: Asset?
```

- **Asset**: Parent asset (`.nullify` on delete)

#### Transaction Types

```swift
enum TransactionType: String, Codable {
    case buy            // Purchase of asset
    case sell           // Sale of asset
    case dividend       // Dividend payment received
    case interest       // Interest payment received
    case deposit        // Cash deposit
    case withdrawal     // Cash withdrawal
    case transfer       // Transfer between accounts
}
```

#### Computed Properties

```swift
// Net amount after fees
var netAmount: Decimal {
    transactionType == .buy ? -(totalAmount + (fees ?? 0)) : (totalAmount - (fees ?? 0))
}

// Impact on quantity
var quantityImpact: Decimal {
    transactionType == .sell ? -quantity : quantity
}
```

#### Usage Example

```swift
let transaction = Transaction(
    transactionType: .buy,
    transactionDate: Date(),
    quantity: 10,
    pricePerUnit: 150.00,
    totalAmount: 1500.00,
    currency: "USD",
    fees: 4.95
)
```

______________________________________________________________________

### InvestmentPlan

Represents an investment strategy or goal with defined parameters.

**File**: `AssetFlow/Models/InvestmentPlan.swift`

#### Properties

| Property              | Type         | Description                | Required |
| --------------------- | ------------ | -------------------------- | -------- |
| `id`                  | `UUID`       | Unique identifier          | ✓        |
| `name`                | `String`     | Display name               | ✓        |
| `planDescription`     | `String?`    | Detailed objectives        | ✗        |
| `startDate`           | `Date`       | Plan start date            | ✓        |
| `endDate`             | `Date?`      | Target completion date     | ✗        |
| `targetAmount`        | `Decimal?`   | Goal amount                | ✗        |
| `monthlyContribution` | `Decimal?`   | Planned monthly investment | ✗        |
| `riskTolerance`       | `RiskLevel`  | Risk acceptance level      | ✓        |
| `status`              | `PlanStatus` | Current status             | ✓        |
| `notes`               | `String?`    | Strategy details           | ✗        |
| `createdDate`         | `Date`       | Creation timestamp         | ✓        |
| `lastUpdated`         | `Date`       | Last modification          | ✓        |

#### Risk Levels

```swift
enum RiskLevel: String, Codable {
    case veryLow    // Minimal risk (conservative)
    case low        // Low risk
    case moderate   // Balanced
    case high       // High risk
    case veryHigh   // Maximum risk (aggressive)
}
```

#### Plan Status

```swift
enum PlanStatus: String, Codable {
    case active     // Currently being followed
    case paused     // Temporarily suspended
    case completed  // Goal achieved
    case cancelled  // No longer pursuing
}
```

#### Computed Properties

```swift
// Projected total if following contribution plan
var projectedTotal: Decimal {
    // Calculate based on monthlyContribution and time to endDate
}

// Progress percentage toward goal
var progressPercentage: Decimal {
    // Current value vs targetAmount
}

// Time remaining
var daysRemaining: Int {
    // Days until endDate
}
```

#### Usage Example

```swift
let plan = InvestmentPlan(
    name: "Retirement by 2050",
    planDescription: "Build retirement nest egg",
    startDate: Date(),
    endDate: Calendar.current.date(byAdding: .year, value: 25, to: Date()),
    targetAmount: 1_000_000.00,
    monthlyContribution: 2000.00,
    riskTolerance: .moderate,
    status: .active
)
```

______________________________________________________________________

## Entity Relationships

### Relationship Diagram

```
┌──────────────┐
│  Portfolio   │
│              │
│ - name       │
│ - isActive   │
└──────┬───────┘
       │ 1:Many
       │ (deleteRule: .nullify)
       ↓
┌──────────────┐
│    Asset     │
│              │
│ - name       │
│ - assetType  │
│ - value      │
└──────┬───────┘
       │ 1:Many
       │ (deleteRule: .cascade)
       ↓
┌──────────────┐
│ Transaction  │
│              │
│ - type       │
│ - amount     │
│ - date       │
└──────────────┘

┌──────────────┐
│InvestmentPlan│  (Currently independent)
│              │
│ - name       │
│ - target     │
│ - risk       │
└──────────────┘
```

### Delete Rules

| Relationship         | Delete Rule | Behavior                                    |
| -------------------- | ----------- | ------------------------------------------- |
| Portfolio → Assets   | `.nullify`  | Assets remain, `portfolio` set to `nil`     |
| Asset → Transactions | `.cascade`  | Deleting asset deletes all its transactions |
| Asset → Portfolio    | `.nullify`  | Deleting asset doesn't affect portfolio     |
| Transaction → Asset  | `.nullify`  | Deleting transaction doesn't affect asset   |

### Relationship Constraints

- An Asset can belong to **0 or 1** Portfolio
- A Portfolio can contain **0 to many** Assets
- An Asset can have **0 to many** Transactions
- A Transaction must relate to **0 or 1** Asset
- InvestmentPlan is currently **standalone** (future: link to Portfolio)

______________________________________________________________________

## SwiftData Configuration

### Model Container Setup

**Location**: `AssetFlowApp.swift`

```swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Asset.self,
        Portfolio.self,
        Transaction.self,
        InvestmentPlan.self
    ])

    let modelConfiguration = ModelConfiguration(
        schema: schema,
        isStoredInMemoryOnly: false
    )

    do {
        return try ModelContainer(
            for: schema,
            configurations: [modelConfiguration]
        )
    } catch {
        fatalError("Could not create ModelContainer: \(error)")
    }
}()
```

### Adding New Models

When adding a new model to the schema:

1. Create the model file in `AssetFlow/Models/`
1. Add `@Model` macro to the class
1. Register in `AssetFlowApp.swift` Schema
1. Update this documentation
1. Update `AssetFlow/Models/README.md`
1. Consider migration strategy if needed

### Querying Data

Using SwiftUI's `@Query`:

```swift
@Query(sort: \Portfolio.createdDate, order: .reverse)
private var portfolios: [Portfolio]

@Query(filter: #Predicate<Asset> { $0.portfolio?.id == portfolioId })
private var assets: [Asset]
```

### Manual Context Access

```swift
@Environment(\.modelContext) private var modelContext

// Insert
modelContext.insert(newAsset)

// Delete
modelContext.delete(asset)

// Save (usually automatic)
try? modelContext.save()
```

______________________________________________________________________

## Data Validation

### Model-Level Validation

Validation logic should be in models or ViewModels:

```swift
extension Asset {
    var isValid: Bool {
        !name.isEmpty &&
        currentValue >= 0 &&
        quantity >= 0
    }

    func validate() throws {
        guard isValid else {
            throw ValidationError.invalidAsset
        }
    }
}
```

### Business Rules

1. **Asset Values**: Must be non-negative
1. **Quantities**: Must be positive for owned assets
1. **Dates**: `purchaseDate` cannot be in future
1. **Allocation**: Portfolio target allocation should sum to 100%
1. **Currency**: Valid ISO 4217 currency codes
1. **Transactions**: Sell quantity ≤ current holdings

______________________________________________________________________

## Data Migration

### Schema Versioning

Future migrations will use SwiftData's migration support:

```swift
// Example migration (future)
let schema = Schema(versionedSchema: SchemaV1.self)

let configuration = ModelConfiguration(
    schema: schema,
    migrationPlan: MigrationPlan(
        [MigrationStage.v1ToV2]
    )
)
```

### Migration Strategy

1. **Additive Changes**: New optional properties (no migration needed)
1. **Transformations**: Property renames or type changes (migration required)
1. **Relationship Changes**: Modify delete rules or cardinality (migration required)

______________________________________________________________________

## Performance Considerations

### Indexing

Consider adding indices for frequently queried properties:

```swift
@Attribute(.index)
var name: String
```

### Lazy Loading

Use relationships judiciously to avoid loading entire object graphs:

```swift
// Only load when needed
if let transactions = asset.transactions {
    // Process transactions
}
```

### Batch Operations

For bulk operations, use batch context:

```swift
let backgroundContext = ModelContext(modelContainer)
await backgroundContext.performInBackground {
    // Bulk operations
}
```

______________________________________________________________________

## Future Enhancements

### Planned Model Extensions

1. **Historical Snapshots**: Time-series data for portfolio values
1. **Price History**: Track asset price changes over time
1. **Categories/Tags**: Flexible asset categorization
1. **Goals**: Link InvestmentPlan to Portfolio
1. **Benchmarks**: Track performance vs indices
1. **Tax Lots**: Capital gains tracking
1. **Multi-Currency**: Exchange rate support
1. **Recurring Transactions**: Automated dividend/contribution tracking

### Data Sync

- CloudKit integration for cross-device sync
- Conflict resolution strategies
- Privacy-preserving sync

### External Integration

- API models for market data services
- Import/Export DTOs for data portability
- Third-party service adapters

______________________________________________________________________

## References

- Source: `AssetFlow/Models/`
- Extensions: `AssetFlow/Utilities/Extensions.swift`
- App Configuration: `AssetFlow/AssetFlowApp.swift`
- Original Documentation: `AssetFlow/Models/README.md`
