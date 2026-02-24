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

- **macOS 15.0+** — Full-featured desktop application (local-first; network used only for exchange rate fetching)

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

### Download & Install

1. Go to the [Releases](https://github.com/Jench2103/asset-flow/releases) page and download the latest `AssetFlow-x.y.z.zip`.

1. Unzip the file and move `AssetFlow.app` to your `/Applications` folder.

1. **First launch — bypass the Gatekeeper warning:**

   Because the app is not signed with an Apple Developer certificate, macOS will block it on first open. To allow it:

   1. Double-click `AssetFlow.app`. You will see a warning that the app cannot be opened.
   1. Open **System Settings → Privacy & Security**.
   1. Scroll down to the **Security** section. You will see a message: _"AssetFlow was blocked from use because it is not from an identified developer."_
   1. Click **Open Anyway**, then authenticate with Touch ID or your password.
   1. In the confirmation dialog, click **Open**.

   The app will open normally on all subsequent launches.

### Build from Source

#### Prerequisites

- Xcode 16.0 or later
- macOS 15.0 or later (for development)
- [swift-format](https://github.com/swiftlang/swift-format/tree/main)
- [SwiftLint](https://github.com/realm/SwiftLint/tree/main)

#### Steps

1. Clone the repository:

   ```bash
   git clone git@github.com:Jench2103/asset-flow.git AssetFlow
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

### VSCode Setup

This project ships with `.vscode/settings.json` that configures SourceKit-LSP for the Xcode build system. To enable accurate cross-file symbol resolution, install [xcode-build-server](https://github.com/SolaWing/xcode-build-server) and generate a local build server config:

```bash
brew install xcode-build-server
xcode-build-server config -scheme AssetFlow -project AssetFlow.xcodeproj
```

This creates a machine-local `buildServer.json` (already in `.gitignore`) that tells SourceKit-LSP how to compile each file with the correct flags. Build in Xcode at least once to populate the index store, then restart the language server in VSCode.

### Code Style

This project uses a combination of `swift-format` and `SwiftLint` to ensure high code quality and a consistent style.

- **`swift-format`**: Used for automated code formatting.
- **`SwiftLint`**: Used to enforce stylistic conventions and catch common errors.

Configurations for these tools can be found in `.swift-format` and `.swiftlint.yml` respectively. Both are run automatically before each commit via pre-commit hooks.

### Architecture

The application follows the MVVM (Model-View-ViewModel) architecture pattern:

- **Models**: SwiftData models (Category, Asset, Snapshot, SnapshotAssetValue, CashFlowOperation, ExchangeRate)
- **Views**: SwiftUI components for UI presentation
- **ViewModels**: `@Observable @MainActor` classes for business logic and state management
- **Services**: Stateless calculation utilities (CalculationService, CSVParsingService, RebalancingCalculator, BackupService, SettingsService, AuthenticationService, CurrencyService, ChartDataService, ExchangeRateService, CurrencyConversionService, DateFormatStyle)

## Features

- Snapshot-based portfolio tracking with point-in-time recording
- CSV import for assets and cash flows with validation and duplicate detection
- Category management with target allocation percentages
- Multi-currency support with automatic exchange rate fetching
- Portfolio-level return analysis (growth rate, Modified Dietz, cumulative TWR, CAGR)
- Rebalancing calculator with suggested buy/sell actions
- Data visualization with pie charts, line charts, and cumulative TWR charts
- Backup and restore via ZIP archive
- Settings for display currency, date format, and default platform
- Optional app lock with Touch ID and system password authentication
- Localization support (English and Traditional Chinese)

## Contributing

This is a personal project. Contributions, issues, and feature requests are welcome.

## License

[Apache License 2.0](LICENSE) — Copyright © 2026 Jen-Chien Chang
