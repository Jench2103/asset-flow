# AssetFlow Architecture

## Overview

AssetFlow is a macOS desktop application (macOS 14.0+) for snapshot-based portfolio management and asset allocation tracking. It is built with SwiftUI, SwiftData, and Swift Charts, following a local-first architecture with no network dependencies.

## Architecture Pattern

### MVVM (Model-View-ViewModel)

The application follows the MVVM architectural pattern to separate concerns and improve testability:

```
+--------------+
|     View     | <- SwiftUI Views (UI Layer)
+------+-------+
       | observes
       v
+--------------+
|  ViewModel   | <- Business Logic & State
+------+-------+
       | uses
       v
+--------------+
|    Model     | <- SwiftData Models (Data Layer)
+------+-------+
       |
       v
+--------------+
|   Services   | <- Stateless Calculations & Utilities
+--------------+
```

### Layer Responsibilities

#### View Layer (SwiftUI)

- **Purpose**: Presentation and user interaction
- **Location**: `AssetFlow/Views/`
- **Characteristics**:
  - Declarative UI with SwiftUI
  - Observes ViewModel state changes
  - Minimal business logic
  - macOS-optimized layouts (sidebar navigation, list-detail split)
  - Reusable components

**Example Structure**:

```swift
struct DashboardView: View {
    @State private var viewModel: DashboardViewModel

    var body: some View {
        // UI declaration
    }
}
```

#### ViewModel Layer

- **Purpose**: Business logic and state management
- **Location**: `AssetFlow/ViewModels/`
- **Characteristics**:
  - Uses `@Observable` macro for automatic change tracking
  - `@MainActor` isolation for UI thread safety
  - Coordinates between Views and Models/Services
  - Handles data transformation and validation
  - Form validation with real-time feedback

**ViewModels** (all 11 implemented and tested):

1. **DashboardViewModel**: Portfolio overview metrics, summary cards, chart data
1. **SnapshotListViewModel**: Snapshot listing, creation, deletion
1. **SnapshotDetailViewModel**: Snapshot detail, asset breakdown, carry-forward resolution, cash flow management
1. **AssetListViewModel**: Asset listing, grouping (by platform or category)
1. **AssetDetailViewModel**: Asset value history, editing, deletion validation
1. **CategoryListViewModel**: Category listing, creation, deletion
1. **CategoryDetailViewModel**: Category detail, value and allocation history
1. **PlatformListViewModel**: Platform listing, rename operations
1. **RebalancingViewModel**: Rebalancing calculations, current vs. target allocation
1. **ImportViewModel**: CSV parsing, validation, preview, import execution
1. **SettingsViewModel**: Display currency, date format, default platform

**Views** (all 12 implemented — navigation shell, all sections, all detail views):

1. **ContentView**: Full sidebar navigation with `SidebarSection` enum, list-detail splits, discard confirmation, post-import navigation
1. **DashboardView**: Summary cards, period performance (1M/3M/1Y), chart placeholders, recent snapshots
1. **SnapshotListView**: `@Query` live list with carry-forward indicators, New Snapshot sheet
1. **SnapshotDetailView**: Asset breakdown with carried-forward distinction (SPEC 8.3), category allocation, cash flow CRUD
1. **AssetListView**: Platform/category grouping, selection binding
1. **AssetDetailView**: Edit fields, sparkline chart, value history, delete validation
1. **CategoryListView**: Add sheet, target allocation warning, delete validation
1. **CategoryDetailView**: Value/allocation history charts, delete validation
1. **PlatformListView**: Rename sheet, empty state
1. **RebalancingView**: Suggestions table, no-target section, summary
1. **ImportView**: CSV import (accepts shared ViewModel from ContentView)
1. **SettingsView**: Currency, date format, default platform

**Example Structure**:

```swift
@Observable
@MainActor
class ImportViewModel {
    var importType: ImportType = .assets
    var selectedFile: URL?
    var snapshotDate: Date = .now
    var selectedPlatform: String?
    var selectedCategory: Category?
    var previewRows: [PreviewRow] = []
    var validationErrors: [ValidationError] = []
    var validationWarnings: [ValidationWarning] = []

    var isImportDisabled: Bool {
        !validationErrors.isEmpty || previewRows.isEmpty
    }

    func parseCSV(_ url: URL) { /* Parse and validate */ }
    func executeImport() { /* Create/update snapshot */ }
}
```

#### Model Layer (SwiftData)

- **Purpose**: Data structure and persistence
- **Location**: `AssetFlow/Models/`
- **Characteristics**:
  - SwiftData `@Model` classes
  - Business entities with relationships
  - Type-safe data structures
  - Computed properties for derived values
  - Schema versioning support

**Core Models**:

- `Category` - Asset categorization with target allocation
- `Asset` - Individual investments identified by (name, platform)
- `Snapshot` - Portfolio state at a specific date
- `SnapshotAssetValue` - Market value of an asset within a snapshot
- `CashFlowOperation` - External cash flow event associated with a snapshot

See [DataModel.md](DataModel.md) for detailed model documentation.

#### Service Layer

- **Purpose**: Stateless calculations, data operations, and utility functions
- **Location**: `AssetFlow/Services/`
- **Characteristics**:
  - Business logic separated from models and ViewModels
  - NOT marked as `@MainActor` (pure functions where possible)
  - No external API integrations (local-only)
  - Stateless calculations
  - Error handling and validation

**Planned Services**:

1. **CarryForwardService**: Resolves composite portfolio values by combining direct snapshot data with carried-forward platform values from prior snapshots. Must operate on pre-fetched data in memory (no N+1 queries).

1. **CSVParsingService**: Parses asset CSV and cash flow CSV files according to the schemas defined in SPEC Section 4.2. Handles encoding (UTF-8 with BOM tolerance), number parsing (strip currency symbols, thousand separators), and validation.

1. **DuplicateDetectionService**: Detects duplicate assets (by normalized name + platform) and duplicate cash flows (by case-insensitive description) both within a CSV file and between CSV data and existing snapshot records.

1. **GrowthRateCalculator**: Calculates simple percentage change in portfolio value between two dates with period lookback logic (1M, 3M, 1Y) and the 14-day staleness threshold.

1. **ModifiedDietzCalculator**: Calculates cash-flow-adjusted returns using the Modified Dietz method, with time-weighting of intermediate cash flows.

1. **TWRCalculator**: Chains Modified Dietz returns between consecutive snapshots to compute cumulative time-weighted return.

1. **CAGRCalculator**: Calculates compound annual growth rate from beginning/ending values and time span.

1. **RebalancingCalculator**: Computes target vs. current allocation differences and suggested buy/sell actions for each category.

1. **BackupService**: Exports all application data to a ZIP archive containing CSV files and a manifest.json. Restores from a backup archive with full validation (file integrity, column headers, foreign key references). **Note**: BackupService requires `@MainActor` annotation because it accepts `ModelContext`, which is `@MainActor`-isolated. This is an exception to the general "services are not `@MainActor`" principle.

1. **SettingsService**: Manages app-wide user preferences (display currency, date format, default platform) via UserDefaults.

1. **CurrencyService**: Provides ISO 4217 currency information (codes, names, flag emojis). Unlike other services, CurrencyService is a class with a `static let shared` singleton because it caches parsed currency data from the bundled ISO 4217 XML file.

**Design Principles**:

- Services perform pure calculations without requiring MainActor
- Models remain simple data containers
- ViewModels coordinate between services and UI
- Testability: mock data can be passed to services without side effects
- All service data types (structs used as inputs/outputs, such as `CompositeSnapshotView`, `AssetCSVResult`, `RebalancingSuggestion`) should conform to `Sendable` for Swift 6 strict concurrency compatibility
- Using `enum` for stateless services naturally avoids actor isolation issues

## Localization

AssetFlow uses Apple's **String Catalogs** (`.xcstrings`) with feature-scoped tables for organization:

- **View Layer**: String literals in SwiftUI (`Text()`, `Label()`, etc.) are auto-extracted into `Localizable.xcstrings` at build time. No manual wrapping needed.
- **ViewModel/Service Layer**: All user-facing strings use `String(localized:table:)` with feature-specific tables (e.g., `Snapshot`, `Asset`, `Category`, `Import`, `Services`).
- **Enum Display Names**: Enums with user-facing values have a `localizedName` computed property for UI display. The `rawValue` is reserved for SwiftData persistence and must never be shown to users.

## Data Flow

### Unidirectional Data Flow

```
User Action -> View -> ViewModel -> Service/Model -> SwiftData
                ^                                      |
                +-------- State Update <---------------+
```

1. **User Interaction**: User interacts with View
1. **Action Dispatch**: View calls ViewModel method
1. **Business Logic**: ViewModel processes request (may use Services)
1. **Data Operation**: Model updates SwiftData
1. **State Update**: Changes propagate back to ViewModel
1. **UI Refresh**: View automatically re-renders

### Carry-Forward Data Flow

A key architectural pattern is the carry-forward resolution for composite portfolio values:

```
Snapshot N requested
       |
       v
Fetch all SnapshotAssetValues for Snapshot N
       |
       v
Identify platforms present in Snapshot N
       |
       v
For each missing platform:
  Find most recent prior snapshot containing that platform
  Include those platform's asset values
       |
       v
Composite portfolio value = direct values + carried-forward values
```

**Important**: Carry-forward values are computed at query time, never stored as new records. The `CarryForwardService` must operate on pre-fetched snapshot history in memory to avoid N+1 database queries.

### SwiftData Integration

- **Single ModelContainer**: Shared container injected at app root in `AssetFlowApp.swift`
- **Automatic Persistence**: No manual `save()` calls required
- **SwiftUI Integration**: `@Query` property wrapper for reactive data binding
- **Schema Registration**: All models registered in `sharedModelContainer`

```swift
@main
struct AssetFlowApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Category.self,
            Asset.self,
            Snapshot.self,
            SnapshotAssetValue.self,
            CashFlowOperation.self,
        ])
        // Container configuration
    }()
}
```

## Platform Support

### macOS Only (v1)

**Platform**: macOS 14.0+

- Full-featured desktop application
- Sidebar navigation with list-detail split views
- Minimum window size: 900 x 600 points
- Collapsible sidebar (default width: 220 points)
- Supports system appearance (light and dark mode)
- Menu bar integration (Settings via Cmd+,)
- Keyboard shortcuts for common actions

**No iOS or iPadOS support** in v1. No platform-specific compiler directives are needed.

## Dependency Management

### Current Dependencies

- **SwiftData**: First-party persistence framework
- **SwiftUI**: UI framework
- **Swift Charts**: Data visualization (pie charts, line charts)
- **Foundation**: Core utilities (including CSV parsing, ZIP handling)

### No External Dependencies

AssetFlow is a local-only application with no network requirements:

- No external API calls
- No API keys
- No `com.apple.security.network.client` entitlement needed
- No third-party packages

### Dependency Injection

ViewModels and Services use dependency injection for testability:

```swift
@Observable
@MainActor
class SnapshotDetailViewModel {
    private let carryForwardService: CarryForwardService

    init(
        snapshot: Snapshot,
        modelContext: ModelContext,
        carryForwardService: CarryForwardService = CarryForwardService()
    ) {
        // ...
    }
}
```

## State Management

### View State

- `@State`: Local view state
- `@Binding`: Two-way bindings
- `@Environment(\.modelContext)`: Access to persistence context

### Data State

- `@Query`: SwiftData reactive queries
- `@Observable` ViewModels: Business logic state

### App State

- `@AppStorage`: User preferences (display currency, date format)
- Custom environment values for configuration

## Error Handling

### Strategy

- Typed errors with custom `Error` conformances
- Error propagation via `throws`
- User-facing error messages (localized)
- Logging for debugging via `os.log` (no `print()` statements)

```swift
enum ImportError: LocalizedError {
    case missingRequiredColumns([String])
    case duplicateAssetsInCSV([(row1: Int, row2: Int, name: String)])
    case duplicateAssetsInSnapshot([(name: String, platform: String)])
    case emptyFile

    var errorDescription: String? {
        // Localized descriptions
    }
}
```

### Calculation Error Handling

- Division by zero: Display "N/A" or "Cannot calculate" with explanation
- Insufficient snapshots for TWR/CAGR: Display "Insufficient data (need at least 2 snapshots)"
- Beginning value \<= 0: Display "Cannot calculate"
- Denominator (BMV + weighted CF) \<= 0: Display "Cannot calculate"
- No snapshot within lookback window: Period metric = N/A

## Performance and Scalability

### Carry-Forward Resolution Performance

The most performance-critical operation is carry-forward resolution. To avoid N+1 queries:

1. **Pre-fetch all snapshot data** needed for the date range
1. **Build an in-memory index** of platforms to their latest values per snapshot
1. **Resolve carry-forward** from the in-memory data structure

This ensures that computing the composite value for any snapshot is O(platforms) rather than O(snapshots * platforms * assets).

### General Optimization Strategies

- **Lazy Loading**: SwiftData automatically lazy loads relationships
- **Efficient Queries**: Use specific, filtered predicates in `@Query`
- **Batch Operations**: Use batch processing for CSV imports (insert all SnapshotAssetValues at once)
- **Background Processing**: Consider background tasks for large CSV imports

### Memory Management

- **ARC**: Swift's Automatic Reference Counting is the primary mechanism
- **SwiftUI**: SwiftUI's struct-based views minimize memory footprint
- **Chart Data**: Compute chart data points lazily as needed for the visible time range

## Security Considerations

### Data Protection

- SwiftData encrypted storage (via file system encryption)
- All data stored locally (no network transmission)
- Backup files are unencrypted ZIP archives (user responsibility to store securely)

### Privacy

- No data collection or telemetry
- No network access
- User owns 100% of their data
- Local-first architecture

See [SecurityAndPrivacy.md](SecurityAndPrivacy.md) for comprehensive security documentation.

## Testing Strategy

See [TestingStrategy.md](TestingStrategy.md) for comprehensive testing approach.

## Build Configuration

### Targets

- **AssetFlow (macOS)**: Desktop application (macOS 14.0+)

### Build Schemes

- **Debug**: Development builds with logging
- **Release**: Optimized production builds

### Configuration Files

- `.swift-format`: Code formatting rules
- `.swiftlint.yml`: Linting configuration
- `.editorconfig`: Editor settings
- `.pre-commit-config.yaml`: Git hooks

## Future Architecture Considerations

### Potential Enhancements

1. **Modular Architecture**: Extract features into Swift Packages
1. **Repository Pattern**: Abstract data persistence layer
1. **iOS/iPadOS Support**: Platform expansion in future versions
1. **Column Mapping**: Configurable CSV column mapping (future version)
1. **Category-Level Cash Flows**: Per-category cash flow tracking (future version)
