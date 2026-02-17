# API and Integration Design

## Preface

**Purpose of this Document**

This document describes the design of internal service APIs and data format specifications for AssetFlow. As a **local-only application with no external API dependencies**, this document focuses exclusively on internal service interfaces, CSV import/export formats, and the backup/restore system.

**What This Document Covers**

- **Internal Service APIs**: Service layer interfaces for CSV parsing, carry-forward resolution, calculations, and backup/restore
- **CSV Import Format**: Asset CSV and Cash Flow CSV schemas, parsing rules, and validation
- **Backup Format**: ZIP archive structure, CSV serialization, and manifest specification
- **Error Handling**: Service-level error types and handling patterns

**What This Document Does NOT Cover**

- User interface design (see [UserInterfaceDesign.md](UserInterfaceDesign.md))
- Business logic calculations (see [BusinessLogic.md](BusinessLogic.md))
- Data model structure (see [DataModel.md](DataModel.md))
- External API integrations (none in v1)

**Design Philosophy**

- **Local-Only**: No network access, no external APIs, no API keys
- **Standard Formats**: CSV for import/export, ZIP for backup archives
- **Deterministic**: All operations produce the same output for the same input
- **Fail-Safe**: Validation before execution; rejected operations leave no partial state

**Related Documentation**

- [Architecture.md](Architecture.md) - MVVM layers and service patterns
- [BusinessLogic.md](BusinessLogic.md) - Calculation formulas and business rules
- [DataModel.md](DataModel.md) - Data structures and relationships

______________________________________________________________________

## Internal Service APIs

### CSVParsingService

**Purpose**: Parse CSV files according to the asset and cash flow schemas defined in SPEC Section 4.2.

```swift
enum CSVParsingService {
    /// Parse an asset CSV file into structured rows
    static func parseAssetCSV(
        url: URL,
        importPlatform: String?,
        importCategory: Category?
    ) throws -> AssetCSVResult

    /// Parse a cash flow CSV file into structured rows
    static func parseCashFlowCSV(url: URL) throws -> CashFlowCSVResult
}

struct AssetCSVResult {
    let rows: [AssetCSVRow]
    let warnings: [CSVWarning]
    let unrecognizedColumns: [String]
}

struct AssetCSVRow {
    let rowNumber: Int
    let assetName: String
    let marketValue: Decimal
    let platform: String  // Resolved via platform handling rules
}

struct CashFlowCSVResult {
    let rows: [CashFlowCSVRow]
    let warnings: [CSVWarning]
    let unrecognizedColumns: [String]
}

struct CashFlowCSVRow {
    let rowNumber: Int
    let description: String  // Maps to CashFlowOperation.cashFlowDescription in the model
    let amount: Decimal
}
```

**Note**: `CashFlowCSVRow.description` represents the "Description" column from the CSV file. When creating `CashFlowOperation` entities, this value is assigned to the `cashFlowDescription` property (not `description`) to avoid conflicts with Swift's built-in `CustomStringConvertible` protocol.

**Parsing Rules**:

- Encoding: UTF-8 (with BOM tolerance)
- Delimiter: comma only
- Number parsing: strip whitespace, currency symbols ($), thousand separators (commas in numbers), parse as `Decimal`
- Empty rows: silently skipped
- Header row: required as first row

**Error Cases**:

```swift
enum CSVParsingError: LocalizedError {
    case fileCannotBeOpened
    case missingRequiredColumns([String])
    case emptyFile
    case noDataRows
    case invalidNumber(row: Int, column: String, value: String)
    case emptyRequiredField(row: Int, column: String)
}
```

______________________________________________________________________

### Duplicate Detection

**Purpose**: Detect duplicates within a CSV and between CSV data and existing snapshot records.

**Implementation**: AssetFlow handles duplicate detection in two layers:

1. **CSV-Internal Duplicates** (handled by `CSVParsingService`):

   - Detected during CSV parsing
   - Asset duplicates: Same (name, platform) within the CSV file (normalized: trim whitespace, collapse spaces, case-insensitive)
   - Cash flow duplicates: Same description within the CSV file (case-insensitive)
   - Returns parsing errors with row numbers for duplicates found

1. **CSV-vs-Snapshot Duplicates** (handled by `ImportViewModel`):

   - Detected when loading preview in import workflow
   - Compares parsed CSV rows against existing snapshot data
   - Asset conflicts: CSV row matches an asset already in the target snapshot
   - Cash flow conflicts: CSV row description matches a cash flow operation already in the target snapshot
   - Surfaces conflicts in the import preview UI for user resolution

**Asset Duplicate Detection**: Two records share the same (Asset Name, Platform) identity using normalized comparison (trim whitespace, collapse spaces, case-insensitive).

**Cash Flow Duplicate Detection**: Two records share the same Description (case-insensitive comparison).

______________________________________________________________________

### CarryForwardService

**Purpose**: Resolve composite portfolio values by combining direct snapshot data with carried-forward platform values from prior snapshots.

```swift
enum CarryForwardService {
    /// Compute the composite view for a snapshot (direct + carried-forward values)
    static func resolveCompositeView(
        for snapshot: Snapshot,
        allSnapshots: [Snapshot],
        allAssetValues: [SnapshotAssetValue]
    ) -> CompositeSnapshotView

    /// Compute composite views for all snapshots (batch, for charts)
    static func resolveAllCompositeViews(
        snapshots: [Snapshot],
        allAssetValues: [SnapshotAssetValue]
    ) -> [CompositeSnapshotView]
}

struct CompositeSnapshotView {
    let snapshot: Snapshot
    let directValues: [SnapshotAssetValue]
    let carriedForwardValues: [CarriedForwardValue]
    let totalValue: Decimal
}

struct CarriedForwardValue {
    let asset: Asset
    let marketValue: Decimal
    let sourceSnapshotDate: Date  // Which snapshot this was carried from
}
```

**Implementation Requirement**: Must operate on pre-fetched data in memory. The caller pre-fetches all snapshots and asset values, then passes them to the service. No database queries inside the service.

______________________________________________________________________

### CalculationService

**Purpose**: Unified calculation engine for all financial metrics. All methods are pure functions operating on `Decimal` values.

**File**: `AssetFlow/Services/CalculationService.swift`

```swift
enum CalculationService {
    /// Calculate simple growth rate between two values (SPEC Section 10.3)
    /// Formula: (endValue - beginValue) / beginValue
    /// - Returns: Growth rate as a decimal (e.g., 0.10 for 10%), or nil if
    ///   beginning value is zero or negative
    static func growthRate(
        beginValue: Decimal,
        endValue: Decimal
    ) -> Decimal?

    /// Calculate Modified Dietz return (SPEC Section 10.4)
    /// Formula: R = (EMV - BMV - CF) / (BMV + sum(wi * CFi))
    /// Where wi = (totalDays - daysSinceStart) / totalDays
    /// - Parameters:
    ///   - beginValue: Beginning composite portfolio value (BMV)
    ///   - endValue: Ending composite portfolio value (EMV)
    ///   - cashFlows: Array of (amount, daysSinceStart) tuples for intermediate cash flows
    ///   - totalDays: Total calendar days in the period
    /// - Returns: Modified Dietz return as a decimal, or nil if denominator is <= 0
    ///   or beginning value is zero/negative
    static func modifiedDietzReturn(
        beginValue: Decimal,
        endValue: Decimal,
        cashFlows: [(amount: Decimal, daysSinceStart: Int)],
        totalDays: Int
    ) -> Decimal?

    /// Calculate cumulative time-weighted return by chaining period returns (SPEC Section 10.5)
    /// Formula: TWR = (1 + r1) * (1 + r2) * ... * (1 + rn) - 1
    /// - Parameter periodReturns: Array of Modified Dietz returns for consecutive periods
    /// - Returns: Cumulative TWR as a decimal
    static func cumulativeTWR(
        periodReturns: [Decimal]
    ) -> Decimal

    /// Calculate compound annual growth rate (SPEC Section 10.6)
    /// Formula: CAGR = (endValue / beginValue) ^ (1 / years) - 1
    /// - Parameters:
    ///   - beginValue: Beginning portfolio value
    ///   - endValue: Ending portfolio value
    ///   - years: Number of years (can be fractional)
    /// - Returns: CAGR as a decimal, or nil if beginning value is zero/negative
    ///   or years is zero/negative
    static func cagr(
        beginValue: Decimal,
        endValue: Decimal,
        years: Double
    ) -> Decimal?

    /// Calculate category allocation percentage (SPEC Section 10.2)
    /// Formula: categoryValue / totalValue * 100
    /// - Returns: Allocation percentage, or 0 if total value is zero
    static func categoryAllocation(
        categoryValue: Decimal,
        totalValue: Decimal
    ) -> Decimal
}
```

### RebalancingCalculator

**Purpose**: Computes rebalancing adjustments for portfolio allocation.

**File**: `AssetFlow/Services/RebalancingCalculator.swift`

```swift
enum RebalancingCalculator {
    /// Calculate the adjustment amount needed to reach target allocation
    /// - Parameters:
    ///   - currentAllocation: Current allocation percentage (0-100)
    ///   - targetAllocation: Target allocation percentage (0-100)
    ///   - totalPortfolioValue: Total portfolio value
    /// - Returns: Signed Decimal (positive = buy, negative = sell)
    static func adjustment(
        currentAllocation: Decimal,
        targetAllocation: Decimal,
        totalPortfolioValue: Decimal
    ) -> Decimal
}
```

**Return Value Convention**: All calculation methods return `nil` (not throwing) when the result is N/A (insufficient data, division by zero, etc.). The ViewModel maps `nil` to the appropriate display text ("N/A", "Cannot calculate", etc.).

______________________________________________________________________

### BackupService

**Purpose**: Export all application data to a ZIP archive and restore from a backup archive.

**Note**: BackupService requires `@MainActor` because it accepts `ModelContext`, which is `@MainActor`-isolated. This is an exception to the general service layer principle that services are not `@MainActor`.

```swift
@MainActor
enum BackupService {
    /// Export all data to a ZIP archive at the specified URL
    static func exportBackup(
        to url: URL,
        modelContext: ModelContext,
        settingsService: SettingsService
    ) throws

    /// Validate a backup archive without modifying data
    static func validateBackup(
        at url: URL
    ) throws -> BackupManifest

    /// Restore all data from a backup archive (replaces ALL existing data)
    static func restoreFromBackup(
        at url: URL,
        modelContext: ModelContext,
        settingsService: SettingsService
    ) throws
}

struct BackupManifest: Codable {
    let formatVersion: Int
    let exportTimestamp: String  // ISO 8601
    let appVersion: String
}
```

**Export Format**: ZIP archive containing:

- `manifest.json` -- format version, export timestamp, app version
- `categories.csv` -- all Category records
- `assets.csv` -- all Asset records
- `snapshots.csv` -- all Snapshot records
- `snapshot_asset_values.csv` -- all SnapshotAssetValue records
- `cash_flow_operations.csv` -- all CashFlowOperation records
- `settings.csv` -- user preferences with columns: `key`, `value`. Keys: `displayCurrency` (e.g., "USD"), `dateFormat` (e.g., "abbreviated"), `defaultPlatform` (e.g., "" or "Interactive Brokers")

**ZIP Implementation**: Uses `/usr/bin/ditto` via `Process` for ZIP creation (`-c -k --sequesterRsrc`) and extraction (`-x -k`). No external dependencies required — `ditto` is built into macOS.

**CSV Serialization Rules**:

- Column headers match data model field names (see [DataModel.md](DataModel.md))
- UUID fields: standard UUID string format
- Decimal fields: full precision (no rounding)
- Date fields: ISO 8601 format (YYYY-MM-DD)
- Optional/nullable fields: empty string for null
- These CSV files are internal to the backup format, not intended for user editing

**Restore Validation**:

Before modifying any data, the restore operation validates:

1. All expected CSV files are present in the archive
1. All CSV files are parseable with correct column headers
1. All foreign key references are valid across files:
   - Every `assetID` in `snapshot_asset_values.csv` exists in `assets.csv`
   - Every `snapshotID` in `snapshot_asset_values.csv` exists in `snapshots.csv`
   - Every `snapshotID` in `cash_flow_operations.csv` exists in `snapshots.csv`
   - Every `categoryID` in `assets.csv` references an existing Category or is null

If validation fails, the restore is rejected with a detailed error listing all violations. No data is modified.

**Error Cases**:

```swift
enum BackupError: LocalizedError {
    case invalidArchive
    case missingFile(String)
    case invalidCSVHeaders(file: String, expected: [String], found: [String])
    case invalidForeignKey(file: String, row: Int, field: String, value: String)
    case corruptedData(details: String)
}
```

______________________________________________________________________

### SettingsService

**Purpose**: Manage app-wide user preferences with `@Observable` reactivity.

SettingsService is an `@Observable @MainActor class` with a shared singleton and support for test isolation via `createForTesting()`. Properties use `didSet` to persist to UserDefaults immediately:

```swift
@Observable
@MainActor
class SettingsService {
    static let shared = SettingsService()

    var mainCurrency: String       // Default: "USD"
    var dateFormat: DateFormatStyle // Default: .abbreviated
    var defaultPlatform: String    // Default: ""

    static func createForTesting() -> SettingsService
}
```

**DateFormatStyle**: A `String`-backed `CaseIterable` enum with cases `.numeric`, `.abbreviated`, `.long`, `.complete`. Maps to `Date.FormatStyle.DateStyle` for rendering and provides `localizedName` and `preview(for:)`.

**Usage in ViewModels**:

```swift
let service = settingsService ?? SettingsService.shared
self.selectedCurrency = service.mainCurrency
```

Changes are applied immediately via `didSet` and persisted to UserDefaults.

______________________________________________________________________

### CurrencyService

**Purpose**: Provides ISO 4217 currency information.

```swift
class CurrencyService {
    static let shared = CurrencyService()

    var currencies: [Currency]

    struct Currency: Identifiable {
        let code: String   // e.g., "USD"
        let name: String   // e.g., "US Dollar"
        var flag: String   // e.g., flag emoji
        var displayName: String  // e.g., "USD - US Dollar"
    }
}
```

Parses bundled ISO 4217 XML file. Filters duplicates and fund currencies.

______________________________________________________________________

### ChartDataService

**Purpose**: Stateless service for chart data filtering by time range and Y-axis label abbreviation.

**File**: `AssetFlow/ViewModels/ChartDataService.swift`

```swift
enum ChartTimeRange: String, CaseIterable, Identifiable {
    case oneWeek = "1W"
    case oneMonth = "1M"
    case threeMonths = "3M"
    case sixMonths = "6M"
    case oneYear = "1Y"
    case threeYears = "3Y"
    case fiveYears = "5Y"
    case all = "All"

    /// Returns the start date for this range relative to a reference date,
    /// or nil for `.all` (no filtering)
    func startDate(from referenceDate: Date) -> Date?
}

protocol ChartFilterable {
    var chartDate: Date { get }
}

enum ChartDataService {
    /// Filters chart data points by time range
    /// Uses the latest data point's date as reference, not Date.now
    static func filter<T: ChartFilterable>(_ items: [T], range: ChartTimeRange) -> [T]

    /// Returns abbreviated string for large numeric values
    /// Examples: 3,000,000,000 → "3B", 2,000,000 → "2M", 5,000 → "5K"
    static func abbreviatedLabel(for value: Decimal) -> String
}
```

**Usage**: Chart views use `ChartDataService.filter()` to apply time range selection before rendering. `ChartFilterable` protocol is conformed to by all chart data point types (`DashboardDataPoint`, `CategoryValueHistoryEntry`, `CategoryAllocationHistoryEntry`).

**Axis Labels**: Y-axis labels use `abbreviatedLabel(for:)` to format large values (K/M/B) for readability in compact chart layouts.

______________________________________________________________________

## CSV Import Format Specification

### Asset CSV

**Required columns** (exact header names):

| Column         | Description                      |
| -------------- | -------------------------------- |
| `Asset Name`   | Name of the asset                |
| `Market Value` | Current market value as a number |

**Optional columns**:

| Column     | Description                                                          |
| ---------- | -------------------------------------------------------------------- |
| `Platform` | Platform/brokerage name (overridden by import-level platform if set) |

**Sample**:

```csv
Asset Name,Market Value,Platform
AAPL,15000,Interactive Brokers
VTI,28000,Interactive Brokers
Bitcoin,5000,Coinbase
Savings Account,20000,Chase Bank
```

### Cash Flow CSV

**Required columns** (exact header names):

| Column        | Description                           |
| ------------- | ------------------------------------- |
| `Description` | Description of the cash flow          |
| `Amount`      | Positive = inflow, negative = outflow |

**Sample**:

```csv
Description,Amount
Salary deposit,50000
Emergency fund transfer,-10000
Dividend reinvestment,1500
```

### Column Mapping

Column mapping is deferred to a future version. For v1, CSV files must use the exact column names specified above. The app must display the expected schema and provide downloadable sample CSVs.

______________________________________________________________________

## Error Handling Patterns

### Service Error Strategy

- Services throw typed errors (enums conforming to `LocalizedError`)
- ViewModels catch errors and map to user-facing messages
- All errors include context (which file, which row, which field)

### User-Facing Error Display

- Import errors: Inline in the import preview (per-row indicators)
- Backup/restore errors: Alert dialog with detailed error description
- Calculation errors: "N/A" or "Cannot calculate" inline text

### Developer Logging

- Log errors with `os.log` (not `print()`)
- Include context (which service, which operation)
- No sensitive data in logs (no financial values)

______________________________________________________________________

## Build Phase: Commit Hash Injection

A `PBXShellScriptBuildPhase` named **"Inject Git Commit"** runs after the Resources phase on every build (not deploy-only). It writes the current git short commit hash into the built product's `Info.plist` under the `AppCommit` key:

```bash
#!/bin/bash
set -e
COMMIT=$(git -C "$SRCROOT" rev-parse --short HEAD 2>/dev/null || echo "unknown")
if [ -n "$(git -C "$SRCROOT" status --porcelain 2>/dev/null)" ]; then
  COMMIT="${COMMIT}-dev"
fi
/usr/libexec/PlistBuddy -c "Set :AppCommit $COMMIT" "$BUILT_PRODUCTS_DIR/$INFOPLIST_PATH"
```

**Key details:**

- The source `AssetFlow/Info.plist` contains `AppCommit = "unknown"` as a committed placeholder. The script only overwrites the **built** copy.
- A `-dev` suffix is appended when the working tree is dirty, making development builds visually distinguishable.
- `ENABLE_USER_SCRIPT_SANDBOXING = NO` is set in the target-level build settings (both Debug and Release) to allow the script to invoke `git` and `/usr/libexec/PlistBuddy`.
- `Constants.AppInfo.commit` reads this value at runtime via `Bundle.main.infoDictionary?["AppCommit"]`.

______________________________________________________________________

## Explicit Non-Goals (v1)

The following are NOT implemented:

- Real-time market price fetching
- Brokerage API integration
- Exchange rate API
- Cloud sync / iCloud integration
- Multi-currency FX conversion
- Column mapping for CSV import
- Data export for reporting (CSV, PDF) -- backup/restore IS supported
- Webhooks or push notifications
- Any network communication

______________________________________________________________________

## References

- [Architecture.md](Architecture.md) - Service layer design
- [BusinessLogic.md](BusinessLogic.md) - Calculation formulas
- [DataModel.md](DataModel.md) - Entity definitions for CSV serialization
- Specification: `SPEC.md` Sections 3.10, 4, 7, 13, 14, 15
