# AssetFlow Source Code

## Directory Structure

| Directory     | Purpose                                                                             |
| ------------- | ----------------------------------------------------------------------------------- |
| `Models/`     | SwiftData `@Model` classes (see `Models/README.md` for full reference)              |
| `Views/`      | SwiftUI view structs                                                                |
| `ViewModels/` | `@Observable @MainActor` classes for form state and business logic                  |
| `Services/`   | Stateless utilities: CurrencyService, ExchangeRateService, PortfolioValueCalculator |
| `Utilities/`  | Extensions and helpers (e.g., `Decimal.formatted(currency:)`)                       |
| `Resources/`  | Non-code assets (XML data files, etc.)                                              |

## Patterns

### ViewModel

```swift
@Observable
@MainActor
class FooFormViewModel {
  // Form fields with real-time validation via didSet
  var name: String = "" {
    didSet {
      guard name != oldValue else { return }
      hasUserInteracted = true
      validateName()
    }
  }
  var nameValidationMessage: String?
  var hasUserInteracted = false

  // Disable save until valid
  var isSaveDisabled: Bool { /* validation logic */ }

  // Persist changes
  func save() { /* modelContext.insert(...) */ }
}
```

Key points:

- `@Observable` for SwiftUI reactivity (not `ObservableObject`/`@Published`)
- `@MainActor` for thread safety
- `didSet` on form properties triggers validation; guard against same-value sets
- Interaction flags (`hasUserInteracted`) to defer showing errors until user edits
- `isSaveDisabled` computed property drives UI button state
- `save()` uses injected `ModelContext` for persistence

### View

```swift
struct FooFormView: View {
  @State var viewModel: FooFormViewModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.modelContext) private var modelContext

  var body: some View { /* ... */ }
}
```

Key points:

- `@State var viewModel` (not `@StateObject` — using Observation framework)
- `@Environment(\.dismiss)` for navigation
- Platform conditionals with `#if os(macOS)` / `#if os(iOS)`

### Model

```swift
@Model
final class Foo {
  var id: UUID
  var amount: Decimal  // Always Decimal for money

  @Relationship(deleteRule: .cascade)
  var children: [Bar]? = []

  @Relationship(deleteRule: .nullify)
  var parent: Baz?
}
```

Key points:

- `@Model` macro, `final class`
- `Decimal` for all monetary values (never Float/Double)
- Explicit `@Relationship` with delete rules (`.cascade` or `.nullify`)
- Register new models in `AssetFlowApp.swift` `sharedModelContainer` Schema

### Service

Services are stateless structs or classes with no direct SwiftData dependency:

- **CurrencyService** — singleton (`static let shared`), loads ISO 4217 currency data
- **ExchangeRateService** — `@Observable @MainActor`, fetches rates from Coinbase API with 1-hour cache
- **PortfolioValueCalculator** — pure `struct` with static calculation methods

### Localization

String Catalogs (`.xcstrings`) organize localized strings by feature:

- **Views**: String literals in `Text()`, `Label()`, etc. auto-extract into `Localizable.xcstrings`.
- **ViewModels/Services**: Use `String(localized:table:)` with feature tables (`Asset`, `Portfolio`, `Transaction`, `PriceHistory`, `Services`).
- **Enums**: Use `localizedName` for display; `rawValue` is for SwiftData persistence only.

```swift
// ViewModel validation message
nameValidationMessage = String(localized: "Asset name cannot be empty.", table: "Asset")

// Enum display in views
Text(asset.assetType.localizedName)  // not .rawValue
```

## Naming Conventions

- PascalCase with descriptive suffix: `AssetFormViewModel`, `AssetFormView`, `CurrencyService`
- File name matches primary type name: `AssetFormViewModel.swift`
- Views: `*View`, `*Row`, `*Section`
- ViewModels: `*ViewModel`
- Services: `*Service`, `*Calculator`
