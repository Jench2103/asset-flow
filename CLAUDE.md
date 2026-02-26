# CLAUDE.md

## Project Overview

AssetFlow is a macOS 15.0+ desktop app for snapshot-based portfolio management and asset allocation tracking. Built with SwiftUI, SwiftData, and Swift Charts. Local-first; network access limited to exchange rate fetching (cdn.jsdelivr.net).

## Build Commands

```bash
xcodebuild -project AssetFlow.xcodeproj -scheme AssetFlow build
xcodebuild -project AssetFlow.xcodeproj -scheme AssetFlow test -destination 'platform=macOS'
swift-format format --in-place --recursive --parallel .
swift-format lint --strict --recursive --parallel .
swiftlint --fix
```

## Architecture

MVVM with SwiftData. Models: `@Model` classes (see `Models/README.md`). Views: SwiftUI. ViewModels: `@Observable @MainActor` classes. Services: stateless utilities (see `AssetFlow/CLAUDE.md`).

```
Category (1:Many) → Asset
Asset (Many:Many via SnapshotAssetValue) → Snapshot
Snapshot (1:Many) → SnapshotAssetValue
Snapshot (1:Many) → CashFlowOperation
Snapshot (1:1) → ExchangeRate
```

All models registered in `SchemaV1` (`Models/SchemaVersioning.swift`). When adding models, update `SchemaV1.models`, `Models/README.md`, and `Documentation/DataModel.md`.

**Xcode:** When adding files/features, update targets, `Info.plist`, entitlements, and scheme configs as needed.

## Documentation

Source of truth: `Documentation/SPEC.md`. Design docs in `Documentation/`: Architecture, DataModel, DevelopmentGuide, CodeStyle, TestingStrategy, UserInterfaceDesign, BusinessLogic, SecurityAndPrivacy, APIDesign.

Before completing any task, review and update affected docs. Key mappings:

| Change Type              | Update                             |
| ------------------------ | ---------------------------------- |
| Add/modify model         | `Models/README.md`, `DataModel.md` |
| Architecture/service     | `Architecture.md`, `APIDesign.md`  |
| UI/screen                | `UserInterfaceDesign.md`           |
| Business rule            | `BusinessLogic.md`                 |
| Security/privacy         | `SecurityAndPrivacy.md`            |
| Testing approach         | `TestingStrategy.md`               |
| Coding convention        | `CodeStyle.md`                     |
| Build command/dependency | `DevelopmentGuide.md`, this file   |

**Markdown conventions:** Use `1.` for all ordered list items. Don't manually adjust table column widths (`mdformat` hook handles it).

## Code Quality

- `swift-format` (config: `.swift-format`) and `SwiftLint` (config: `.swiftlint.yml`)
- Pre-commit hooks run both automatically. Manual: `pre-commit run --all-files`
- Fix all compilation warnings before committing — treat warnings as errors

## Critical Conventions

- **Financial data**: Always `Decimal` for monetary values (never Float/Double). See `AssetFlow/CLAUDE.md` for `formattedPercentage()` details.
- **Localization**: String Catalogs (`.xcstrings`), English + Traditional Chinese (`zh-Hant`). See `AssetFlow/CLAUDE.md` for patterns.
- **Commits**: [Conventional Commits](https://www.conventionalcommits.org/en/v1.0.0/) — `type(scope): description`. Types: `feat`, `fix`, `refactor`, `ci`, `build`, `chore`, `docs`, `style`, `test`, `perf`. Scope optional but encouraged (e.g., `feat(dashboard):`). Breaking changes: append `!` (e.g., `feat!:`) or add `BREAKING CHANGE:` footer.
- **Testing**: Swift Testing (`import Testing`), NOT XCTest. TDD: red-green-refactor. See `AssetFlowTests/CLAUDE.md`.
- **Tooltip help text**: Always use `.helpWhenUnlocked("…")` instead of `.help("…")`. The app uses `AuthenticationService` for app lock; `.help()` exposes tooltip content on the lock screen, while `.helpWhenUnlocked()` only shows tooltips after the user has authenticated.
- **Hover interactions**: Always use `.onHoverWhenUnlocked()` and `.onContinuousHoverWhenUnlocked()` instead of `.onHover()` and `.onContinuousHover()`. Hover effects (chart tooltips, highlights) can leak data through the lock overlay. See `AssetFlow/Utilities/WhenUnlockedModifiers.swift`.
- **macOS only (v1)**: No iOS/iPadOS. No `#if os(...)` needed.
