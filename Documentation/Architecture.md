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
- **Location**: `AssetFlow/ViewModels/` (to be implemented)
- **Characteristics**:
  - Conforms to `ObservableObject`
  - Publishes state changes via `@Published` properties
  - Coordinates between Views and Models/Services
  - Platform-agnostic logic
  - Handles data transformation and validation

**Example Structure**:

```swift
@MainActor
class PortfolioViewModel: ObservableObject {
    @Published var portfolios: [Portfolio] = []
    private let dataService: DataService

    func fetchPortfolios() async { }
    func createPortfolio(_ portfolio: Portfolio) async { }
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
- `InvestmentPlan` - Strategic goals

See [DataModel.md](DataModel.md) for detailed model documentation.

#### Service Layer

- **Purpose**: Data operations and external integrations
- **Location**: `AssetFlow/Services/` (to be implemented)
- **Characteristics**:
  - Data access abstraction
  - SwiftData query operations
  - External API integrations (future)
  - Business logic helpers
  - Error handling and validation

**Planned Services**:

```swift
protocol DataService {
    func fetch<T: PersistentModel>(_ modelType: T.Type) async throws -> [T]
    func save<T: PersistentModel>(_ model: T) async throws
    func delete<T: PersistentModel>(_ model: T) async throws
}

protocol PriceService {
    func fetchCurrentPrice(for symbol: String) async throws -> Decimal
}
```

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

## Performance Optimization

### Strategies

- Lazy loading of data
- Pagination for large datasets
- Background processing for heavy operations
- Efficient SwiftData queries with predicates
- View hierarchy optimization

### Memory Management

- ARC (Automatic Reference Counting)
- Weak references to avoid retain cycles
- Lazy initialization of heavy resources

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
