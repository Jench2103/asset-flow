# Data Model Documentation

## Overview

AssetFlow uses SwiftData for type-safe, modern data persistence on macOS 14.0+. The data model is designed around a **snapshot-based portfolio tracking** approach, where portfolio state is captured at discrete points in time rather than derived from transaction history.

This document provides comprehensive documentation for all data models, including property definitions, relationships, uniqueness constraints, SwiftData configuration, validation rules, and usage examples.

## Core Principles

### Snapshot-Based Design

The data model captures portfolio state through snapshots rather than transactions:

- **Snapshots** represent the best-known portfolio state at a specific date
- **SnapshotAssetValues** record market values of assets within a snapshot
- **Carry-forward** computes missing platform values from prior snapshots at query time (not stored)
- **CashFlowOperations** record external money flows for return calculations

### Financial Data Precision

- **Always use `Decimal`** for monetary values (never `Float` or `Double`)
- Prevents floating-point rounding errors in financial calculations
- Default display currency: `"USD"` (cosmetic only, no FX conversion)
- Currency-aware formatting via extensions
- `Decimal` is natively supported by SwiftData (via Foundation's `NSDecimalNumber` bridging) -- no explicit `@Attribute(.transformable)` annotation is needed

### Relationship Design

- Clear parent-child relationships
- Cascade delete rules for snapshot data integrity
- SwiftData relationships for entity references
- Uniqueness constraints enforced at the model level

### Schema Management

- All models registered in `AssetFlowApp.swift` `sharedModelContainer`
- SwiftData lightweight migration relied upon for schema evolution
- Initial data model designed to minimize future breaking changes
- When adding models, update both Schema and this documentation

## Model Entities

### Category

Represents a user-defined grouping for assets (e.g., "Equities", "Bonds", "Cash") with an optional target allocation percentage for rebalancing.

**File**: `AssetFlow/Models/Category.swift`

#### Properties

| Property                     | Type       | Description                             | Required |
| ---------------------------- | ---------- | --------------------------------------- | -------- |
| `id`                         | `UUID`     | Primary key                             | Yes      |
| `name`                       | `String`   | Display name (unique, case-insensitive) | Yes      |
| `targetAllocationPercentage` | `Decimal?` | Target allocation (0-100), optional     | No       |

#### Relationships

```swift
@Relationship(deleteRule: .deny, inverse: \Asset.category)
var assets: [Asset]?
```

- **Assets**: Assets assigned to this category (`.deny` on delete -- category cannot be deleted if assets are assigned)

#### Uniqueness Constraints

```swift
#Unique<Category>([\.name])
```

- `name` must be unique (case-insensitive comparison)
- **Note**: The `#Unique` macro enforces uniqueness at the SwiftData level, but case-insensitive uniqueness must be handled in business logic (ViewModel validation).

#### Validation Rules

- `name` must not be empty
- `targetAllocationPercentage`, if provided, must be between 0 and 100
- Target allocations across all categories should sum to 100% (warning if not, but not blocked)
- Categories without a target allocation are excluded from rebalancing calculations

#### Usage Example

```swift
let category = Category(
    name: "Equities",
    targetAllocationPercentage: 60.0
)
```

______________________________________________________________________

### Asset

Represents an individual investment identified by the tuple (name, platform). Assets persist across snapshots and are created during import if they don't already exist.

**File**: `AssetFlow/Models/Asset.swift`

#### Properties

| Property   | Type     | Description                                                                                              | Required           |
| ---------- | -------- | -------------------------------------------------------------------------------------------------------- | ------------------ |
| `id`       | `UUID`   | Primary key                                                                                              | Yes                |
| `name`     | `String` | Asset name (e.g., "AAPL", "Bitcoin", "Savings Account")                                                  | Yes                |
| `platform` | `String` | Platform/brokerage name. Always present as `String`, but may be an empty string to indicate no platform. | Yes (may be empty) |

#### Relationships

```swift
@Relationship(deleteRule: .nullify, inverse: \Category.assets)
var category: Category?

@Relationship(deleteRule: .deny, inverse: \SnapshotAssetValue.asset)
var snapshotAssetValues: [SnapshotAssetValue]?
```

- **Category**: Optional assignment (`.nullify` -- if the category is deleted, this becomes nil)
- **SnapshotAssetValues**: All value records across snapshots (`.deny` -- asset cannot be deleted while it has snapshot values)

**Note on SwiftData relationships vs. SPEC field names**: The SPEC defines `categoryID: UUID?` as a field on Asset. In SwiftData, this is modeled using a direct relationship property (`category: Category?`) rather than a manual UUID foreign key. SwiftData manages the underlying foreign key automatically. Access the category's UUID via `asset.category?.id` when needed (e.g., for backup serialization).

#### Uniqueness Constraints

```swift
#Unique<Asset>([\.name, \.platform])
```

- `(name, platform)` must be unique (case-insensitive, using normalized identity comparison)
- **Note**: The `#Unique` macro enforces uniqueness at the SwiftData level, but case-insensitive uniqueness cannot be enforced by the macro alone and must be handled in business logic (ViewModel validation).

#### Identity Matching

During import or manual operations, assets are matched using **normalized identity comparison**:

1. Trim leading and trailing whitespace
1. Collapse multiple consecutive spaces to a single space
1. Case-insensitive comparison (Unicode-aware, using `caseInsensitiveCompare` or equivalent)

#### Deletion Rules

An asset can only be deleted when it has **no SnapshotAssetValue records** in any snapshot. When associations exist, the delete action is disabled with explanatory text: "This asset cannot be deleted because it has values in [N] snapshot(s). Remove the asset from all snapshots first."

#### Usage Example

```swift
let asset = Asset(
    name: "AAPL",
    platform: "Interactive Brokers"
)
asset.category = equitiesCategory
```

______________________________________________________________________

### Snapshot

Represents the best-known portfolio state at a specific date. A snapshot is uniquely identified by its date. Multiple imports on the same date add SnapshotAssetValues to the existing snapshot.

**File**: `AssetFlow/Models/Snapshot.swift`

#### Properties

| Property    | Type   | Description                                                                                | Required |
| ----------- | ------ | ------------------------------------------------------------------------------------------ | -------- |
| `id`        | `UUID` | Primary key                                                                                | Yes      |
| `date`      | `Date` | Calendar date (normalized to local midnight, no time component). Must be today or earlier. | Yes      |
| `createdAt` | `Date` | Auto-set creation timestamp                                                                | Yes      |

#### Relationships

```swift
@Relationship(deleteRule: .cascade, inverse: \SnapshotAssetValue.snapshot)
var assetValues: [SnapshotAssetValue]?

@Relationship(deleteRule: .cascade, inverse: \CashFlowOperation.snapshot)
var cashFlowOperations: [CashFlowOperation]?
```

- **SnapshotAssetValues**: Asset values recorded in this snapshot (`.cascade` on delete)
- **CashFlowOperations**: Cash flow events associated with this snapshot (`.cascade` on delete)

#### Uniqueness Constraints

- Only one Snapshot may exist per `date`

#### Important Notes

- `totalPortfolioValue` is **not stored** -- it is always derived by summing SnapshotAssetValues (including carry-forward)
- Future dates are not allowed
- The `date` field stores only the calendar date (no time component), normalized to local midnight

#### Usage Example

```swift
let snapshot = Snapshot(
    date: Calendar.current.startOfDay(for: Date())
)
```

______________________________________________________________________

### SnapshotAssetValue

Records the market value of a specific asset within a specific snapshot. This is the core join entity connecting snapshots to assets with their values.

**File**: `AssetFlow/Models/SnapshotAssetValue.swift`

#### Properties

| Property      | Type      | Description               | Required |
| ------------- | --------- | ------------------------- | -------- |
| `marketValue` | `Decimal` | Market value of the asset | Yes      |

**Note on SPEC field names**: The SPEC defines `snapshotID` and `assetID` as UUID foreign keys. In SwiftData, these are modeled as relationship properties (`snapshot` and `asset`) rather than manual UUID fields. SwiftData manages the underlying foreign keys automatically. Access UUIDs via `snapshot?.id` and `asset?.id` when needed (e.g., for backup serialization). Do not store both a relationship property and a manual UUID field for the same reference.

#### Relationships

```swift
var snapshot: Snapshot?  // Inverse of Snapshot.assetValues
var asset: Asset?        // Inverse of Asset.snapshotAssetValues
```

- **Snapshot**: Parent snapshot. Deletion is governed by the parent's delete rule (Snapshot -> assetValues uses `.cascade`, so deleting a Snapshot cascades to its SnapshotAssetValues).
- **Asset**: The asset being valued. Deletion is governed by the parent's delete rule (Asset -> snapshotAssetValues uses `.deny`, so the asset cannot be deleted while SnapshotAssetValues reference it).

**Note**: The child-side delete rule is not meaningful in SwiftData -- deletion behavior is controlled by the parent-side rule. The inverse relationships here exist to satisfy SwiftData's relationship modeling requirements.

#### Uniqueness Constraints

- `(snapshot, asset)` must be unique (one value per asset per snapshot). Enforced in business logic since compound uniqueness across relationships requires ViewModel validation.

#### Notes

- Negative market values are allowed (for liabilities or short positions)
- Zero market values are allowed (with a warning during import)
- Carry-forward values are NOT stored as SnapshotAssetValue records -- they are computed at query time

#### Usage Example

```swift
let value = SnapshotAssetValue(marketValue: 15000)
value.snapshot = snapshot
value.asset = asset
context.insert(value)
```

______________________________________________________________________

### CashFlowOperation

Records an external money flow (deposit or withdrawal) associated with a snapshot. Cash flows are needed for accurate Modified Dietz return calculations.

**File**: `AssetFlow/Models/CashFlowOperation.swift`

#### Properties

| Property              | Type      | Description                                           | Required |
| --------------------- | --------- | ----------------------------------------------------- | -------- |
| `id`                  | `UUID`    | Primary key                                           | Yes      |
| `cashFlowDescription` | `String`  | Description of the cash flow (e.g., "Salary deposit") | Yes      |
| `amount`              | `Decimal` | Positive = inflow, negative = outflow                 | Yes      |

**Note on property naming**: The property is named `cashFlowDescription` (not `description`) to avoid conflict with Swift's built-in `CustomStringConvertible` protocol requirement. This is an implementation detail — the SPEC uses "description" in CSV columns and documentation.

**Note on SPEC field names**: The SPEC defines `snapshotID` as a UUID foreign key. In SwiftData, this is modeled as a relationship property (`snapshot`) rather than a manual UUID field. Access the snapshot UUID via `snapshot?.id` when needed (e.g., for backup serialization).

#### Relationships

```swift
var snapshot: Snapshot?  // Inverse of Snapshot.cashFlowOperations
```

- **Snapshot**: Parent snapshot. Deletion governed by Snapshot -> cashFlowOperations `.cascade` rule.

#### Uniqueness Constraints

- `(snapshotID, cashFlowDescription)` must be unique (case-insensitive comparison on cashFlowDescription)

#### Notes

- The net cash flow for a snapshot is always derived: `netCashFlow = sum(CashFlowOperation.amount)` for all operations associated with that snapshot
- If a snapshot has no cash flow operations, net cash flow = 0 (assumes all value changes are due to investment returns)
- All cash flow operations within a snapshot are assumed to occur at the snapshot date for Modified Dietz time-weighting purposes
- Portfolio-level only in v1 (category-level cash flow tracking deferred)

#### Usage Example

```swift
let cashFlow = CashFlowOperation(
    cashFlowDescription: "Salary deposit",
    amount: 50000
)
cashFlow.snapshot = snapshot
context.insert(cashFlow)
```

______________________________________________________________________

## Entity Relationships

### Relationship Diagram

```
+-----------+
| Category  |
+-----+-----+
      | 1:Many
      v
+-----------+   1:Many   +--------------------+
|   Asset   +----------->| SnapshotAssetValue |
+-----------+            +----------+---------+
                                    |
                                    | Many:1
                                    v
                              +-----------+   1:Many   +--------------------+
                              |  Snapshot  +----------->| CashFlowOperation |
                              +-----------+            +--------------------+
```

### Delete Rules

| Relationship                    | Delete Rule | Behavior                                       |
| ------------------------------- | ----------- | ---------------------------------------------- |
| Category -> Assets              | `.deny`     | Cannot delete category if assets are assigned  |
| Asset -> SnapshotAssetValues    | `.deny`     | Cannot delete asset if snapshot values exist   |
| Snapshot -> SnapshotAssetValues | `.cascade`  | Deleting snapshot removes all its asset values |
| Snapshot -> CashFlowOperations  | `.cascade`  | Deleting snapshot removes all its cash flows   |

**Note**: Delete behavior is controlled by the parent-side rule. Child-side inverse relationships do not independently define delete behavior in SwiftData.

**Important: Category Deletion Protection**

SwiftData's `.deny` delete rule has known bugs and may not work reliably. **Business logic MUST enforce deletion prevention** by checking whether the category has any assigned assets before allowing deletion:

```swift
func deleteCategory(_ category: Category) throws {
    guard category.assets?.isEmpty ?? true else {
        throw CategoryError.cannotDeleteWithAssignedAssets
    }
    modelContext.delete(category)
}
```

**Important: Asset Deletion Protection**

Asset deletion is blocked at the SwiftData level via the `.deny` delete rule. Additionally, business logic MUST enforce deletion prevention and provide a clear error message:

```swift
func deleteAsset(_ asset: Asset) throws {
    guard asset.snapshotAssetValues?.isEmpty ?? true else {
        throw AssetError.cannotDeleteWithSnapshotValues(
            count: asset.snapshotAssetValues?.count ?? 0
        )
    }
    modelContext.delete(asset)
}
```

### Relationship Constraints

- An Asset can belong to **0 or 1** Category
- A Category can contain **0 to many** Assets
- A Snapshot can have **0 to many** SnapshotAssetValues
- A Snapshot can have **0 to many** CashFlowOperations
- An Asset can have **0 to many** SnapshotAssetValues (across different snapshots)
- A SnapshotAssetValue belongs to exactly **1** Snapshot and **1** Asset

______________________________________________________________________

## SwiftData Configuration

### Model Container Setup

**Location**: `AssetFlowApp.swift`

```swift
var sharedModelContainer: ModelContainer = {
    let schema = Schema([
        Category.self,
        Asset.self,
        Snapshot.self,
        SnapshotAssetValue.self,
        CashFlowOperation.self,
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
@Query(sort: \Snapshot.date, order: .reverse)
private var snapshots: [Snapshot]

@Query(sort: \Asset.name)
private var assets: [Asset]

@Query(sort: \Category.name)
private var categories: [Category]
```

### Manual Context Access

```swift
@Environment(\.modelContext) private var modelContext

// Insert
modelContext.insert(newSnapshot)

// Delete
modelContext.delete(snapshot)

// Save (usually automatic)
try? modelContext.save()
```

______________________________________________________________________

## Data Validation

### Model-Level Validation

Validation logic resides in ViewModels (not models):

```swift
// In ImportViewModel
func validateAssetCSV(_ rows: [CSVRow]) -> [ValidationError] {
    var errors: [ValidationError] = []

    for (index, row) in rows.enumerated() {
        if row.assetName.trimmingCharacters(in: .whitespaces).isEmpty {
            errors.append(.emptyAssetName(row: index + 1))
        }
        if Decimal(string: row.marketValue) == nil {
            errors.append(.invalidMarketValue(row: index + 1))
        }
    }

    return errors
}
```

### Business Rules

1. **Market Values**: Use `Decimal` for all monetary values
1. **Dates**: Snapshot dates cannot be in the future; normalized to local midnight
1. **Uniqueness**: (Asset name, Platform) must be unique; Snapshot date must be unique; (Snapshot, Asset) must be unique per SnapshotAssetValue; (Snapshot, Description) must be unique for cash flows
1. **Category Deletion**: Only allowed if no assets are assigned
1. **Asset Deletion**: Only allowed if no SnapshotAssetValue records exist
1. **Snapshot Deletion**: Always allowed (with confirmation dialog); cascades to all asset values and cash flow operations

______________________________________________________________________

## Carry-Forward Behavior

Carry-forward is a **query-time computation**, not a storage operation:

1. When computing the composite total value of Snapshot N:
   - Sum all directly-recorded SnapshotAssetValues in Snapshot N
   - Identify platforms present in Snapshot N (platforms with at least one direct SnapshotAssetValue)
   - For each platform NOT present in Snapshot N, find the most recent prior snapshot containing that platform
   - Include those carried-forward platform values in the total
1. Carry-forward values are **never stored** as new SnapshotAssetValue records
1. Carry-forward operates at the **platform level**: if a platform appears in a snapshot (has any directly-recorded asset), no individual asset carry-forward occurs for that platform
1. Assets absent from a platform's import are treated as disposed (not individually carried forward)

See [BusinessLogic.md](BusinessLogic.md) for detailed carry-forward resolution logic.

______________________________________________________________________

## Backup Data Format

When exporting a backup, each entity is serialized to CSV with the following rules:

- Column headers match field names from this data model
- UUID fields serialized as standard UUID strings
- Decimal fields serialized at full precision
- Date fields use ISO 8601 format (YYYY-MM-DD)
- Optional/nullable fields use an empty string for null values
- A `manifest.json` file includes format version, export timestamp, and app version

See [APIDesign.md](APIDesign.md) for detailed backup format specification.

______________________________________________________________________

## Data Migration

### Schema Versioning

Future migrations will use SwiftData's lightweight migration support:

```swift
// Example migration (future)
let schema = Schema(versionedSchema: SchemaV1.self)
```

### Migration Strategy

1. **Additive Changes**: New optional properties (no migration needed)
1. **Transformations**: Property renames or type changes (migration required)
1. **Relationship Changes**: Modify delete rules or cardinality (migration required)

The initial data model is designed to minimize future breaking changes by:

- Using UUID primary keys
- Keeping relationships simple
- Avoiding complex computed stored properties

______________________________________________________________________

## Performance Considerations

### Efficient Historical Queries

The data model must support efficient queries for:

- Fetching all snapshots (ordered by date)
- Fetching asset values across multiple snapshots (for charts)
- Carry-forward resolution (pre-fetch snapshot history, resolve in memory)

### Indexing

Consider adding indices for frequently queried properties:

```swift
@Attribute(.index)
var date: Date  // On Snapshot

@Attribute(.index)
var name: String  // On Asset
```

### Carry-Forward Performance

Carry-forward computation must be efficient:

1. Pre-fetch all relevant snapshot data into memory
1. Build platform-to-latest-values index
1. Resolve carry-forward from in-memory data
1. Avoid per-asset or per-platform database queries during resolution

______________________________________________________________________

## References

- Source: `AssetFlow/Models/`
- Extensions: `AssetFlow/Utilities/Extensions.swift`
- App Configuration: `AssetFlow/AssetFlowApp.swift`
- Quick Reference: `AssetFlow/Models/README.md`
- Specification: `SPEC.md` Section 7
