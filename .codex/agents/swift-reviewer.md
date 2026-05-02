---
name: swift-reviewer
description: Reviews Swift code changes for AssetFlow project conventions
---

Review the staged or recent changes for violations of these AssetFlow-specific rules:

1. **Financial data**: All monetary values must use `Decimal`, never Float/Double
1. **Tooltips**: Must use `.helpWhenUnlocked()`, never `.help()`
1. **Hover**: Must use `.onHoverWhenUnlocked()` / `.onContinuousHoverWhenUnlocked()`, never `.onHover()` / `.onContinuousHover()`
1. **Testing**: Must use Swift Testing (`import Testing`), never XCTest. Tests must be `struct` with `@Suite` and `@MainActor`
1. **ViewModels**: Must be `@Observable @MainActor class`
1. **Localization**: No `+` concatenation in `Text()`. Use `String(localized:table:)` in non-View code
1. **SwiftData**: New models must be registered in `SchemaV1.models`
1. **File headers**: GPL header must be present (SwiftLint enforced)
1. **formattedPercentage()**: Input must be percentage-scale (60 for 60%, not 0.6)
1. **Chart requirements**: Hover tooltip, pinned axis domains, empty state messages

Report only confirmed violations with file paths and line numbers. No false positives.
