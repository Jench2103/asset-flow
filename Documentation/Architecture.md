# AssetFlow Architecture

## Overview

AssetFlow is built using modern Apple platform technologies with a focus on maintainability, scalability, and cross-platform consistency across macOS, iOS, and iPadOS.

## Architecture Pattern

### MVVM (Model-View-ViewModel)

The application follows the MVVM architectural pattern to separate concerns and improve testability:

```
┌──────────────┐
│     View     │ ← SwiftUI Views (UI Layer)
└──────┬───────┘
       │ observes
       ↓
┌──────────────┐
│  ViewModel   │ ← Business Logic & State
└──────┬───────┘
       │ uses
       ↓
┌──────────────┐
│    Model     │ ← SwiftData Models (Data Layer)
└──────┬───────┘
       │
       ↓
┌──────────────┐
│   Services   │ ← Data Operations & External APIs
└──────────────┘
```

### Layer Responsibilities

#### View Layer (SwiftUI)

- **Purpose**: Presentation and user interaction
- **Location**: `AssetFlow/Views/`
- **Characteristics**:
  - Declarative UI with SwiftUI
  - Observes ViewModel state changes
  - Minimal business logic
  - Platform-specific adaptations using `#if os()` compiler directives
  - Reusable components

**Example Structure**:

```swift
struct PortfolioView: View {
    @StateObject private var viewModel: PortfolioViewModel

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
  - Platform-agnostic logic
  - Handles data transformation and validation
  - Form validation with real-time feedback

**Implemented ViewModels**:

1. **PortfolioFormViewModel**: Portfolio creation and editing

   - Form state management (name, description)
   - Real-time name validation (empty, uniqueness)
   - Whitespace trimming and warning
   - User interaction tracking

1. **PortfolioDetailViewModel**: Portfolio detail view state

   - Asset list management
   - Total value computation
   - Portfolio metadata display

1. **PortfolioManagementViewModel**: Portfolio list and operations

   - Portfolio listing
   - Deletion with validation
   - Empty state handling

1. **AssetFormViewModel**: Asset creation and editing

   - Form state management (name, type, quantity, price, notes)
   - Comprehensive validation (name, quantity, current value)
   - Automatic transaction and price history creation for new assets
   - Edit mode: updates asset properties only (quantity/price via transactions)

**Example Structure**:

```swift
@Observable
@MainActor
class AssetFormViewModel {
    var name: String
    var assetType: AssetType
    var quantity: String
    var currentValue: String

    var nameValidationMessage: String?
    var quantityValidationMessage: String?

    var isSaveDisabled: Bool {
        nameValidationMessage != nil || quantityValidationMessage != nil
    }

    func save() { /* Creates or updates asset */ }
    private func validateName() { /* Validation logic */ }
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

- `Asset` - Individual investments
- `Portfolio` - Asset collections
- `Transaction` - Financial operations
- `PriceHistory` - Historical price points for assets
- `InvestmentPlan` - Strategic goals

See [DataModel.md](DataModel.md) for detailed model documentation.

#### Service Layer

- **Purpose**: Data operations, business logic, and external integrations
- **Location**: `AssetFlow/Services/`
- **Characteristics**:
  - Business logic separated from models and ViewModels
  - NOT marked as `@MainActor` (pure functions where possible)
  - External API integrations
  - Stateless calculations
  - Error handling and validation

**Implemented Services**:

1. **ExchangeRateService**: Fetches and caches exchange rates from Coinbase API

   - Singleton pattern (`shared` instance)
   - 1-hour caching to reduce API calls
   - Configurable base currency via `init(baseCurrency:)`
   - Static `convert()` method for currency conversion (nonisolated)
   - Comprehensive error handling with categorized messages

1. **PortfolioValueCalculator**: Calculates portfolio values with currency conversion

   - Pure struct (no state, not @MainActor)
   - Static method for calculating total value across multiple currencies
   - Takes array of assets and exchange rates as parameters
   - Keeps models free from business logic

1. **CurrencyService**: Provides ISO 4217 currency information

   - Parses ISO 4217 XML for currency codes and names
   - Generates flag emojis for currencies
   - Filters duplicate and fund currencies
   - Singleton pattern (`shared` instance)

**Example Usage**:

```swift
// Exchange rate conversion (nonisolated, can be called from any context)
let convertedValue = ExchangeRateService.convert(
    amount: 100,
    from: "EUR",
    to: "USD",
    using: exchangeRates,
    baseCurrency: "USD"
)

// Portfolio value calculation (nonisolated)
let totalValue = PortfolioValueCalculator.calculateTotalValue(
    for: assets,
    using: exchangeRates,
    targetCurrency: "USD",
    ratesBaseCurrency: "USD"
)
```

**Design Principles**:

- Services perform pure calculations without requiring MainActor
- Models remain simple data containers
- ViewModels coordinate between services and UI
- Testability: mock data can be passed to services without network calls

## Data Flow

### Unidirectional Data Flow

```
User Action → View → ViewModel → Service/Model → SwiftData
                ↑                                      ↓
                └──────── State Update ←───────────────┘
```

1. **User Interaction**: User interacts with View
1. **Action Dispatch**: View calls ViewModel method
1. **Business Logic**: ViewModel processes request
1. **Data Operation**: Service/Model updates SwiftData
1. **State Update**: Changes propagate back to ViewModel
1. **UI Refresh**: View automatically re-renders

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
            Asset.self,
            Portfolio.self,
            Transaction.self,
            PriceHistory.self,
            InvestmentPlan.self
        ])
        // Container configuration
    }()
}
```

## Platform Support

### Multi-Platform Strategy

**Primary Platform**: macOS

- Full-featured implementation
- Priority for new features
- Desktop-optimized layouts

**Secondary Platforms**: iOS, iPadOS

- Core feature parity
- Platform-specific UI adaptations
- Touch-optimized interactions

### Platform-Specific Code

Use compiler directives for platform differences:

```swift
#if os(macOS)
    .frame(minWidth: 800, minHeight: 600)
#elseif os(iOS)
    .navigationBarTitleDisplayMode(.large)
#endif
```

### Responsive Design

- Adaptive layouts using SwiftUI's size classes
- Shared components with platform variants
- Progressive disclosure for complex features

## Dependency Management

### Current Dependencies

- **SwiftData**: First-party persistence framework
- **SwiftUI**: UI framework
- **Foundation**: Core utilities

### Future Dependencies

- Swift Charts (data visualization)
- Swift Testing (testing framework)
- CloudKit (sync capabilities)

### Dependency Injection

ViewModels and Services use dependency injection for testability:

```swift
class PortfolioViewModel: ObservableObject {
    private let dataService: DataService

    init(dataService: DataService = DefaultDataService()) {
        self.dataService = dataService
    }
}
```

## State Management

### View State

- `@State`: Local view state
- `@Binding`: Two-way bindings
- `@StateObject`: ViewModel lifecycle ownership
- `@ObservedObject`: ViewModel observation without ownership

### Data State

- `@Query`: SwiftData reactive queries
- `@Environment(\.modelContext)`: Access to persistence context

### App State

- `@Environment`: Shared app-level state
- `@AppStorage`: User preferences
- Custom environment values for configuration

## Error Handling

### Strategy

- Typed errors with custom `Error` conformances
- Error propagation via `throws`/`async throws`
- User-facing error messages
- Logging for debugging (no `print()` statements)

```swift
enum DataError: LocalizedError {
    case fetchFailed
    case saveFailed(underlying: Error)

    var errorDescription: String? {
        // Localized descriptions
    }
}
```

## Security Considerations

### Data Protection

- SwiftData encrypted storage
- Keychain for sensitive data (future)
- Secure API communication (future)

### Privacy

- Minimal data collection
- Local-first architecture
- Optional cloud sync with user consent

## Performance and Scalability

### Calculation Strategy: Real-Time vs. Snapshotting

A critical architectural decision is how to compute an asset's state (e.g., quantity, cost basis) from its history. This involves a trade-off between immediate data integrity and long-term performance.

**Phase 1 (MVP): Real-Time Calculation**

- **Strategy**: For the initial release, all asset states will be calculated on-the-fly from the full history of `Transaction` and `PriceHistory` records.
- **Benefit**: This approach guarantees 100% data accuracy and is simpler to implement, making it ideal for the MVP.
- **Drawback**: Performance will degrade as a user accumulates many years of data.

**Phase 2 and Beyond: Snapshotting for Performance**

- **Strategy**: To ensure the application remains fast for long-term users, a **snapshotting** mechanism will be introduced. A background process will periodically calculate and store the state of an asset in a separate `AssetSnapshot` model.
- **Benefit**: When displaying an asset, the app will only need to load the latest snapshot and the few transactions that have occurred since. This provides near-instant access to both current and historical data, which is essential for timeline charts.

This phased approach allows for rapid initial development while establishing a clear, robust plan for future scalability.

### General Optimization Strategies

- **Lazy Loading**: SwiftData automatically lazy loads relationships, preventing large object graphs from being loaded into memory at once.
- **Efficient Queries**: Use specific, filtered predicates in `@Query` to fetch only the necessary data.
- **Background Processing**: For intensive operations like generating snapshots, use background tasks to avoid blocking the main thread.

### Memory Management

- **ARC**: Swift's Automatic Reference Counting is the primary mechanism.
- **Weak References**: Use `weak` references in custom classes where necessary to prevent retain cycles (e.g., delegates).
- **SwiftUI**: SwiftUI's struct-based views help minimize memory footprint.

## Testing Strategy

See [TestingStrategy.md](TestingStrategy.md) for comprehensive testing approach.

## Build Configuration

### Targets

- **AssetFlow (macOS)**: Primary desktop application
- **AssetFlow (iOS)**: Mobile application
- **AssetFlow (iPadOS)**: Tablet application

### Build Schemes

- **Debug**: Development builds with logging
- **Release**: Optimized production builds

### Configuration Files

- `.swift-format`: Code formatting rules
- `.swiftlint.yml`: Linting configuration
- `.editorconfig`: Editor settings
- `.pre-commit-config.yaml`: Git hooks

## Future Architecture Enhancements

### Planned Additions

1. **Modular Architecture**: Extract features into Swift Packages
1. **Repository Pattern**: Abstract data persistence layer
1. **Coordinator Pattern**: Navigation management
1. **Use Cases/Interactors**: Complex business logic isolation
1. **CloudKit Integration**: Cross-device synchronization
1. **Widget Extension**: Home screen widgets
1. **Share Extension**: Import from other apps

### Scalability Considerations

- Feature modules for code organization
- Protocol-oriented design for flexibility
- Composition over inheritance
- Clear boundaries between layers
