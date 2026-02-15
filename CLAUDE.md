# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AssetFlow is a macOS desktop application (macOS 14.0+) for snapshot-based portfolio management and asset allocation tracking. It is built with SwiftUI, SwiftData, and Swift Charts, following a local-first architecture with no network dependencies.

## Build Commands

```bash
# Open project
open AssetFlow.xcodeproj

# Build from command line
xcodebuild -project AssetFlow.xcodeproj -scheme AssetFlow build

# Format code with swift-format
swift-format format --in-place --recursive --parallel .

# Lint code with swift-format
swift-format lint --strict --recursive --parallel .

# Lint code with SwiftLint
swiftlint --fix

# Run tests
xcodebuild -project AssetFlow.xcodeproj -scheme AssetFlow test -destination 'platform=macOS'
```

## Architecture

**MVVM Pattern:**

- Models: SwiftData models with relationships
- Views: SwiftUI components
- ViewModels: `@Observable @MainActor` classes handling form state, validation, and persistence
- Services: Stateless utilities (CarryForwardService, CSVParsingService, RebalancingCalculator, BackupService, CurrencyService)

**Data Model Relationships:**

```
Category (1:Many) → Asset
Asset (Many:Many via SnapshotAssetValue) → Snapshot
Snapshot (1:Many) → SnapshotAssetValue
Snapshot (1:Many) → CashFlowOperation
```

All models are registered in `AssetFlowApp.swift` in the `sharedModelContainer` Schema. When adding new models, update both the Schema and `Models/README.md`.

**Xcode Configuration:** When adding new files, features, or dependencies, remember to update Xcode project configuration as needed:

- Add new source files to appropriate targets
- Update `Info.plist` for permissions, capabilities, or app metadata
- Configure build settings for new frameworks or libraries
- Update scheme configurations for testing or deployment
- Add new resources to bundle targets
- Configure entitlements for platform-specific features

**Documentation Updates:** When making changes to the project, keep documentation current. **IMPORTANT: Always check and update relevant design documents.**

Design documents are located in `Documentation/`:

**Specification:**

- `SPEC.md` - Product and technical specification (source of truth for all design decisions)

**Core Documentation:**

- `Architecture.md` - System design, MVVM pattern, layer responsibilities, data flow
- `DataModel.md` - Complete model reference, relationships, SwiftData configuration
- `DevelopmentGuide.md` - Setup, workflows, macOS-specific development
- `CodeStyle.md` - Coding standards, conventions, formatting rules
- `TestingStrategy.md` - Testing approach, patterns, coverage goals

**Design Documentation:**

- `UserInterfaceDesign.md` - UI layouts, navigation, visual design, component patterns
- `BusinessLogic.md` - Business rules, calculations, workflows, validation logic
- `SecurityAndPrivacy.md` - Security measures, privacy principles, threat model
- `APIDesign.md` - Internal API patterns, CSV import/export, backup/restore

**Update checklist by change type:**

| Change Type                 | Update These Documents                                                                       |
| --------------------------- | -------------------------------------------------------------------------------------------- |
| Add/modify SwiftData model  | `Models/README.md` (quick ref), `Documentation/DataModel.md` (full)                          |
| Change architecture pattern | `Documentation/Architecture.md`, this file                                                   |
| Add new layer/service       | `Documentation/Architecture.md`, `Documentation/APIDesign.md`                                |
| New build command/tool      | `Documentation/DevelopmentGuide.md`, this file                                               |
| Coding convention change    | `Documentation/CodeStyle.md`                                                                 |
| Testing approach change     | `Documentation/TestingStrategy.md`                                                           |
| Dependency added            | `Documentation/Architecture.md`, `Documentation/DevelopmentGuide.md`                         |
| Design new screen/UI        | `Documentation/UserInterfaceDesign.md`                                                       |
| Add business rule/calc      | `Documentation/BusinessLogic.md`                                                             |
| Security/privacy change     | `Documentation/SecurityAndPrivacy.md`                                                        |
| API/integration added       | `Documentation/APIDesign.md`                                                                 |
| Major feature (full design) | Multiple: `UserInterfaceDesign.md`, `BusinessLogic.md`, `DataModel.md`, `APIDesign.md`, etc. |

**Before completing any task:**

1. Review which documentation files are affected by your changes
1. Update the relevant documentation files
1. Ensure cross-references between documents remain accurate
1. Update code examples in documentation if APIs changed

**General documentation rules:**

- Add inline code documentation for public APIs and complex logic
- Keep model relationships diagrams current
- Update README.md for user-facing changes

**Markdown Formatting Conventions:**

- **Numbered Lists**: Always use `1.` for all items in ordered lists. Markdown renderers automatically number them correctly. This makes version control diffs cleaner when reordering items.
  ```markdown
  1. First item
  1. Second item
  1. Third item
  ```
- **Tables**: Do NOT manually adjust column widths or alignment. The `mdformat` pre-commit hook handles table formatting automatically. Focus on content, not spacing.

**Code Quality and Formatting:**

This project uses `swift-format` for code formatting and `SwiftLint` for linting.

- **Pre-commit hooks** are configured to run both tools automatically when committing.
- To run manually: `pre-commit run --all-files`
- If hooks fail, fix the issues and commit again.

## Critical Conventions

**Build Warnings:**

- All compilation warnings must be fixed before committing code
- Treat warnings as errors — they often indicate bugs or will become errors in future Swift versions
- Run `xcodebuild build` and verify zero warnings in output

**Financial Data:**

- Always use `Decimal` for monetary values (never Float/Double)
- Default display currency: "USD" (cosmetic only, no FX conversion)
- Extensions in `Utilities/Extensions.swift` provide `.formatted(currency:)` and `.formattedPercentage()`

**Localization:**

- Uses Apple's String Catalogs (`.xcstrings`) with English as development language and Traditional Chinese (`zh-Hant`) as additional language
- SwiftUI view strings are auto-extracted into `Localizable.xcstrings` — no manual wrapping needed
- ViewModel/Service strings use `String(localized:table:)` with feature-scoped tables: `Asset`, `Snapshot`, `Category`, `Import`, `Services`
- Enum display names use `localizedName` computed property — never display `rawValue` directly in UI
- Avoid `+` concatenation in `Text()` — it prevents localization auto-extraction

**File Headers (SwiftLint enforced):**

```swift
//
//  FileName.swift
//  AssetFlow
//
//  Created by [Name] on YYYY/MM/DD.
//
```

**Testing Framework:**

- Uses **Swift Testing** (`import Testing`), NOT XCTest
- Tests use `@Suite`, `@Test`, `#expect()`, and `#require()`
- See `AssetFlowTests/CLAUDE.md` for detailed test patterns

**Test-Driven Development (TDD):**

- Follow the Red-Green-Refactor cycle: write a failing test first, implement the minimum code to pass, then refactor
- Write tests before implementation code for all new features and bug fixes
- Use in-memory SwiftData containers (`ModelConfiguration(isStoredInMemoryOnly: true)`) for test isolation
- Services are stateless and testable with pure input/output — pass mock data directly without side effects
- See `AssetFlowTests/CLAUDE.md` for test structure, naming conventions, and helper patterns

**macOS Only (v1):**

- Target platform: macOS 14.0+ only
- No iOS or iPadOS support in v1 — no platform-specific compiler directives (`#if os(...)`) are needed
- No network access, no API keys, no cloud sync

## Code Quality and Linting

### swift-format

This tool automatically formats Swift code to ensure a consistent style. Configuration is in `.swift-format`.

### SwiftLint

This tool lints the code to enforce stylistic and convention-based rules. Configuration is in `.swiftlint.yml`.

## Core Models

**Category** — Asset categorization with target allocation

- Properties: name (unique, case-insensitive), targetAllocationPercentage (optional, 0-100)
- Relationship: assets (many, `.deny` delete rule — must reassign assets before deleting)

**Asset** — Individual investments identified by (name, platform) tuple

- Properties: name, platform (optional), category (optional)
- Uniqueness: (name, platform) must be unique (case-insensitive)
- Relationships: category (optional, `.nullify`), snapshotAssetValues (many, `.cascade`)

**Snapshot** — Portfolio state at a specific date

- Properties: date (unique, calendar date only), createdAt
- Relationships: snapshotAssetValues (many, `.cascade`), cashFlowOperations (many, `.cascade`)
- Note: `totalPortfolioValue` is always derived (never stored) — includes carry-forward

**SnapshotAssetValue** — Market value of an asset within a snapshot

- Properties: marketValue (Decimal)
- Uniqueness: (snapshotID, assetID) must be unique
- Relationships: snapshot (parent, `.cascade`), asset (parent, `.deny`)

**CashFlowOperation** — External cash flow event associated with a snapshot

- Properties: description (unique per snapshot, case-insensitive), amount (Decimal, positive=inflow, negative=outflow)
- Uniqueness: (snapshotID, description) must be unique
- Relationship: snapshot (parent, `.cascade`)

See `Documentation/DataModel.md` for comprehensive model documentation.

## SwiftData Notes

- Single shared `ModelContainer` injected at app root
- No manual save() calls needed — SwiftData handles persistence automatically
- Carry-forward values are computed at query time, never stored as new records
