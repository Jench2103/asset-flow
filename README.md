# AssetFlow

A macOS desktop application for snapshot-based portfolio management and asset allocation tracking.

## Overview

AssetFlow helps you:

- Track portfolio value over time with snapshot-based recording
- Import asset data from multiple platforms via CSV
- Manage asset categories with target allocation percentages
- Analyze portfolio-level returns (Modified Dietz, TWR, CAGR)
- Calculate rebalancing actions to reach target allocations
- Visualize allocation trends and portfolio growth

## Platform Support

- **macOS 15.0+** — Full-featured desktop application (local-only, no network dependencies)

## Tech Stack

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **Data Visualization**: Swift Charts
- **Minimum Deployment Target**: macOS 15.0+

## Project Structure

```
AssetFlow/
├── Models/          # SwiftData models and entities
├── Views/           # SwiftUI views and UI components
├── ViewModels/      # View models and business logic
├── Services/        # Stateless calculation services
├── Utilities/       # Helper functions and extensions
└── Resources/       # Assets, localization files
```

## Getting Started

### Prerequisites

- Xcode 16.0 or later
- macOS 15.0 or later (for development)
- [swift-format](https://github.com/swiftlang/swift-format/tree/main)
- [SwiftLint](https://github.com/realm/SwiftLint/tree/main)

### Installation

1. Clone the repository:

   ```bash
   git clone git@github.com:Jench2103/asset-flow-swift.git AssetFlow
   cd AssetFlow
   ```

1. Open the project in Xcode:

   ```bash
   open AssetFlow.xcodeproj
   ```

1. Build and run the project (⌘+R)

### Tooling Setup

Install the required code quality tools using Homebrew:

```bash
brew install swift-format
brew install swiftlint
```

These tools are managed by pre-commit hooks, which will automatically format and lint your code before you commit.

## Development

### Code Style

This project uses a combination of `swift-format` and `SwiftLint` to ensure high code quality and a consistent style.

- **`swift-format`**: Used for automated code formatting.
- **`SwiftLint`**: Used to enforce stylistic conventions and catch common errors.

Configurations for these tools can be found in `.swift-format` and `.swiftlint.yml` respectively. Both are run automatically before each commit via pre-commit hooks.

### Architecture

The application follows the MVVM (Model-View-ViewModel) architecture pattern:

- **Models**: SwiftData models (Category, Asset, Snapshot, SnapshotAssetValue, CashFlowOperation)
- **Views**: SwiftUI components for UI presentation
- **ViewModels**: `@Observable @MainActor` classes for business logic and state management
- **Services**: Stateless calculation utilities (CarryForwardService, CSVParsingService, RebalancingCalculator)

## Features

- Snapshot-based portfolio tracking with carry-forward for partial imports
- CSV import for assets and cash flows with validation and duplicate detection
- Category management with target allocation percentages
- Portfolio-level return analysis (growth rate, Modified Dietz, cumulative TWR, CAGR)
- Rebalancing calculator with suggested buy/sell actions
- Data visualization with pie charts, line charts, and cumulative TWR charts
- Backup and restore via ZIP archive
- Settings for display currency, date format, and default platform
- Localization support (English and Traditional Chinese)

## Contributing

This is a personal project. Contributions, issues, and feature requests are welcome.

## License

[To be determined]

## Contact

Jen-Chien Chang
