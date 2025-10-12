# AssetFlow

A comprehensive personal asset allocation monitoring and investment planning application for macOS, iOS, and iPadOS.

## Overview

AssetFlow helps you:

- Monitor personal asset allocation across different investment vehicles
- Record and manage investment planning strategies
- Track investment effectiveness and performance over time
- Visualize portfolio composition and trends

## Platform Support

- **macOS** (Primary) - Full-featured desktop application
- **iOS** - Mobile companion app
- **iPadOS** - Optimized tablet experience

## Tech Stack

- **Language**: Swift
- **UI Framework**: SwiftUI
- **Data Persistence**: SwiftData
- **Minimum Deployment Targets**:
  - macOS 14.0+
  - iOS 17.0+
  - iPadOS 17.0+

## Project Structure

```
AssetFlow/
├── Models/          # Data models and entities
├── Views/           # SwiftUI views and UI components
├── ViewModels/      # View models and business logic
├── Services/        # Data services and API integrations
├── Utilities/       # Helper functions and extensions
└── Resources/       # Assets, localization files
```

## Getting Started

### Prerequisites

- Xcode 26.0 or later
- macOS 26.0 or later
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

- **Models**: Define data structures and SwiftData schemas
- **Views**: SwiftUI components for UI presentation
- **ViewModels**: Business logic and state management
- **Services**: Data operations and external integrations

## Features (Planned)

- [ ] Multi-asset portfolio tracking
- [ ] Investment planning tools
- [ ] Performance analytics and reporting
- [ ] Data visualization and charts
- [ ] Multi-platform sync via iCloud
- [ ] Export capabilities (PDF, CSV)
- [ ] Security and encryption for sensitive data

## Contributing

This is a personal project. Contributions, issues, and feature requests are welcome.

## License

[To be determined]

## Contact

Jen-Chien Chang
