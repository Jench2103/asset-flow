# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

AssetFlow is a multi-platform personal asset allocation and investment tracking application. Platform priority: macOS (primary) → iOS → iPadOS.

**Tech Stack:**
- Swift with SwiftUI
- SwiftData for persistence
- Minimum targets: macOS 14.0+, iOS 17.0+, iPadOS 17.0+

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
```

## Architecture

**MVVM Pattern:**
- Models: SwiftData models with relationships
- Views: SwiftUI components
- ViewModels: Business logic (to be implemented)
- Services: Data operations (to be implemented)

**Data Model Relationships:**
```
Portfolio (1:Many) Asset (1:Many) Transaction
InvestmentPlan (currently standalone)
```

All models are registered in `AssetFlowApp.swift` in the `sharedModelContainer` Schema. When adding new models, update both the Schema and `Models/README.md`.

**Xcode Configuration:**
When adding new files, features, or dependencies, remember to update Xcode project configuration as needed:
- Add new source files to appropriate targets
- Update `Info.plist` for permissions, capabilities, or app metadata
- Configure build settings for new frameworks or libraries
- Update scheme configurations for testing or deployment
- Add new resources to bundle targets
- Configure entitlements for platform-specific features

**Documentation Updates:**
When making changes to the project, keep documentation current:
- Update `Models/README.md` when adding/modifying SwiftData models
- Update this `CLAUDE.md` for architectural changes or new conventions
- Add inline code documentation for public APIs and complex logic
- Update build instructions if new dependencies or tools are added
- Document platform-specific implementations and requirements
- Keep model relationships diagram current in this file

## Critical Conventions

**Financial Data:**
- Always use `Decimal` for monetary values (never Float/Double)
- Default currency: "USD"
- Extensions in `Utilities/Extensions.swift` provide `.formatted(currency:)` and `.formattedPercentage()`

**File Headers (SwiftLint enforced):**
```swift
//
//  FileName.swift
//  AssetFlow
//
//  Created by [Name] on YYYY/MM/DD.
//
```

**Platform-Specific Code:**
```swift
#if os(macOS)
    // macOS-specific code
#endif

#if os(iOS)
    // iOS-specific code
#endif
```

## SwiftLint Key Rules

- Line length: 120 warning, 150 error
- Function body: 60 warning, 100 error
- **Custom rule: No `print()` statements** - use proper logging
- Force unwrapping generates warnings
- Sorted imports required

## Core Models

**Asset** - Individual investments (stocks, bonds, crypto, real estate, etc.)
- Links to Portfolio (optional) and Transactions (many)

**Portfolio** - Asset collections with target allocation
- `totalValue` computed property aggregates asset values
- `targetAllocation: [String: Decimal]?` stores percentages by asset type

**Transaction** - Financial operations (buy/sell/dividend/interest/etc.)
- Links to specific Asset

**InvestmentPlan** - Strategic goals with risk tolerance and status tracking

See `AssetFlow/Models/README.md` for comprehensive model documentation.

## SwiftData Notes

- Single shared `ModelContainer` injected at app root
- No manual save() calls needed - SwiftData handles persistence automatically
- `Item.swift` is legacy from template - remove after updating ContentView
