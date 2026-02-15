# AssetFlow Source Code

## Directory Structure

| Directory     | Purpose                                                                |
| ------------- | ---------------------------------------------------------------------- |
| `Models/`     | SwiftData `@Model` classes (see `Models/README.md` for full reference) |
| `Views/`      | SwiftUI view structs                                                   |
| `ViewModels/` | `@Observable @MainActor` classes for form state and business logic     |
| `Services/`   | Stateless utilities: CurrencyService, SettingsService                  |
| `Utilities/`  | Extensions and helpers (e.g., `Decimal.formatted(currency:)`)          |
| `Resources/`  | Non-code assets (XML data files, etc.)                                 |

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

- `@State var viewModel` (not `@StateObject` -- using Observation framework)
- `@Environment(\.dismiss)` for navigation
- macOS only -- no platform conditionals needed

### Model

```swift
@Model
final class Foo {
  #Unique<Foo>([\.someProperty])

  var id: UUID
  var amount: Decimal  // Always Decimal for money

  @Relationship(deleteRule: .cascade, inverse: \Bar.foo)
  var children: [Bar]?

  @Relationship(deleteRule: .nullify, inverse: \Baz.foos)
  var parent: Baz?
}
```

Key points:

- `@Model` macro, `final class`
- `Decimal` for all monetary values (never Float/Double)
- `#Unique` macro for uniqueness constraints
- Explicit `@Relationship` with delete rules (`.cascade`, `.deny`, or `.nullify`)
- Register new models in `AssetFlowApp.swift` `sharedModelContainer` Schema

### Service

Services are stateless structs or classes with no direct SwiftData dependency:

- **CurrencyService** -- singleton (`static let shared`), loads ISO 4217 currency data
- **SettingsService** -- `@Observable @MainActor`, manages app-wide settings (currency, date format, default platform)
- **BackupService** -- `@MainActor enum`, exports/validates/restores ZIP backup archives using `/usr/bin/ditto`
- **DateFormatStyle** -- `enum`, maps user-selectable date formats to `Date.FormatStyle.DateStyle`

### Localization

String Catalogs (`.xcstrings`) organize localized strings by feature:

- **Views**: String literals in `Text()`, `Label()`, etc. auto-extract into `Localizable.xcstrings`.
- **ViewModels/Services**: Use `String(localized:table:)` with feature tables (`Asset`, `Snapshot`, `Category`, `Import`, `Services`, `Settings`).
- **Enums**: Use `localizedName` for display; `rawValue` is for SwiftData persistence only.

```swift
// ViewModel validation message
nameValidationMessage = String(localized: "Asset name cannot be empty.", table: "Asset")
```

## Naming Conventions

- PascalCase with descriptive suffix: `AssetFormViewModel`, `AssetFormView`, `CurrencyService`
- File name matches primary type name: `AssetFormViewModel.swift`
- Views: `*View`, `*Row`, `*Section`
- ViewModels: `*ViewModel`
- Services: `*Service`, `*Calculator`
