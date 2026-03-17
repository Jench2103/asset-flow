# AssetFlow Source Code

## Directory Structure

| Directory     | Purpose                                                            |
| ------------- | ------------------------------------------------------------------ |
| `Models/`     | SwiftData `@Model` classes (see `Models/README.md`)                |
| `Views/`      | SwiftUI views (includes `Charts/` and `Components/` subdirs)       |
| `ViewModels/` | `@Observable @MainActor` classes for form state and business logic |
| `Services/`   | Stateless utilities (see list below)                               |
| `Utilities/`  | Extensions and helpers (e.g., `Decimal.formatted(currency:)`)      |
| `Resources/`  | Non-code assets (XML data, `.xcstrings` localization catalogs)     |

## Patterns

### ViewModel

`@Observable @MainActor` class handling data loading, saving, and computed aggregates via injected `ModelContext`. Form state (text fields, pickers) lives in View-local `@State` properties; ViewModels expose `save()`/`delete()` and validation methods. Use `@State var viewModel` in views (not `@StateObject`).

### ViewModel Data Reload

ViewModels that compute aggregate/converted values wrap their load method with `withObservationTracking` to auto-reload when any `@Observable`/`@Model` dependency changes:

```swift
func loadData() {
  withObservationTracking {
    performLoadData()
  } onChange: { [weak self] in
    Task { @MainActor [weak self] in
      self?.loadData()
    }
  }
}
private func performLoadData() { /* original load body */ }
```

- `onChange` fires exactly once per registration, then re-registers on next `loadData()` call — no accumulation
- Double `[weak self]` prevents ViewModel retention after container deallocation (critical for tests with in-memory containers)
- Complements `@Query` + `.onChange(of:)` in views for collection membership detection (add/delete objects), which `modelContext.fetch()` inside `withObservationTracking` cannot track
- Explicit `viewModel.loadData()` calls in mutation handlers are intentional — they provide immediate synchronous UI response; `withObservationTracking` handles external changes (e.g., currency switch from Settings)
- Applied to: all ViewModels except `ImportViewModel` and `SettingsViewModel` (no converted aggregate values)

### Model

`@Model final class` with `Decimal` for money, `#Unique` for constraints, explicit `@Relationship` with delete rules (`.cascade`, `.deny`, `.nullify`). Register new models in `SchemaV1.models` (`Models/SchemaVersioning.swift`). Domain error enums (`AssetError`, `CategoryError`, `PlatformError`) also live in `Models/`.

### Services

Stateless enums or classes with no direct SwiftData dependency:

- **CalculationService** -- `enum`, growth rate, Modified Dietz, cumulative TWR, CAGR, category allocation
- **CSVParsingService** -- `enum`, parses asset/cash flow CSV with intra-CSV duplicate detection (cross-snapshot dedup is handled by `ImportViewModel`)
- **RebalancingCalculator** -- `enum`, rebalancing adjustment amounts (buy/sell)
- **BackupService** -- `@MainActor enum`, ZIP backup via `/usr/bin/ditto`
- **SettingsService** -- `@Observable @MainActor class`, app-wide settings (currency, date format, default platform)
- **AuthenticationService** -- `@Observable @MainActor class` singleton, app lock via LocalAuthentication (Touch ID, Apple Watch, system password)
- **CurrencyService** -- `@Observable @MainActor class` singleton (`static let shared`), currency data with UserDefaults caching
- **ExchangeRateService** -- `final class` (`@unchecked Sendable`), fetches rates from cdn.jsdelivr.net, batch-fetches missing rates on launch and after restore, graceful degradation when offline
- **CurrencyConversionService** -- `enum`, stateless currency conversion using ExchangeRate data, returns unconverted values when rates unavailable
- **ChartDataService** -- `enum`, time range filtering, TWR rebasing (`rebasedTWR`), and Y-axis abbreviation
- **DateFormatStyle** -- `enum`, user-selectable date formats → `Date.FormatStyle.DateStyle`

### Localization

- **Views**: String literals in `Text()`, `Label()`, etc. auto-extract into `Localizable.xcstrings`
- **ViewModels/Services**: `String(localized: "message", table: "Asset")` with tables: `Asset`, `Snapshot`, `Category`, `Import`, `Services`, `Settings`, `Platform`, `Rebalancing`
- **Enums**: `localizedName` for display; `rawValue` for persistence only
- Avoid `+` concatenation in `Text()` — prevents auto-extraction

## SwiftData Notes

- Single shared `ModelContainer` injected at app root
- No manual `save()` — SwiftData auto-persists
- Snapshots contain only directly-recorded values; no carry-forward

## SwiftUI Pitfalls

**`formattedPercentage()` expects percentage-scale input:** Pass `Decimal(60)` for 60%, not `0.6`. It divides by 100 internally. Raw decimals like TWR (0.21 for 21%) need `(twr * 100).formattedPercentage()`.

**Stable IDs in computed properties:** Never `let id = UUID()` in structs from computed properties — creates new IDs each render. Use stable composite keys: `var id: String { "\(category)-\(date.timeIntervalSince1970)" }`.

**Optional Picker needs nil tag:** Include `Text("Label").tag(Optional<T>.none)` when `Picker` selection is `Optional<T>`.

**Pin chart axis domains on interactive charts:** Set explicit `.chartXScale(domain:)` and `.chartYScale(domain:)` when using hover/tap overlays with conditional marks, otherwise axes shift during interaction.

**ViewModel empty↔content transitions:** Don't use `.animation(_:value:)` for empty↔content in ViewModel-based views (flashes on load). Use instant swap; `withAnimation` only in user-action handlers (`onChange`, delete). `@Query`-based views can animate safely.

**Use `.helpWhenUnlocked()` not `.help()`:** The app supports app lock via `AuthenticationService`. `.help("…")` tooltips are visible on the lock screen, leaking content. Always use `.helpWhenUnlocked("…")` to restrict tooltips to authenticated sessions.

**Use `.onHoverWhenUnlocked()` and `.onContinuousHoverWhenUnlocked()` instead of `.onHover()` and `.onContinuousHover()`:** Hover interactions (chart tooltips, highlight effects) can leak financial data through the lock overlay. The lock-aware variants gate callbacks behind the `isAppLocked` environment key, resetting hover state (`false` / `.ended`) when locked. Defined in `Utilities/WhenUnlockedModifiers.swift`.

**Chart requirements:** Every chart in `Views/Charts/` needs: hover tooltip (`.annotation()` on `RuleMark` with `overflowResolution` for positioning, `.chartOverlay` + `onContinuousHoverWhenUnlocked` for hover detection), pinned axis domains (`.chartXScale(domain:)` and `.chartYScale(domain:)` to prevent shifts from conditional marks), empty state messages (no data, no data for time range, single data point), click-to-navigate where specified, `ChartTimeRangeSelector` binding.

## Naming

- PascalCase: `AssetFormViewModel`, `AssetFormView`, `CurrencyService`
- File name matches primary type
- Suffixes: `*View`, `*Row`, `*Section`, `*ViewModel`, `*Service`, `*Calculator`

**File headers (SwiftLint enforced):**

```swift
//  AssetFlow — snapshot-based portfolio management for macOS.
//  Copyright (C) 2026 Jen-Chien Chang
//
//  This program is free software: you can redistribute it and/or modify
//  it under the terms of the GNU General Public License as published by
//  the Free Software Foundation, either version 3 of the License, or
//  (at your option) any later version.
//
//  This program is distributed in the hope that it will be useful,
//  but WITHOUT ANY WARRANTY; without even the implied warranty of
//  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//  GNU General Public License for more details.
//
//  You should have received a copy of the GNU General Public License
//  along with this program.  If not, see <https://www.gnu.org/licenses/>.
//
```
