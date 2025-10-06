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
- SwiftLint (optional, recommended)

### Installation

1. Clone the repository:
   ```bash
   git clone git@github.com:Jench2103/asset-flow-swift.git AssetFlow
   cd AssetFlow
   ```

2. Open the project in Xcode:
   ```bash
   open AssetFlow.xcodeproj
   ```

3. Build and run the project (⌘+R)

### SwiftLint Setup

Install SwiftLint using Homebrew:
```bash
brew install swiftlint
```

SwiftLint will automatically run during builds if installed.

## Development

### Code Style

This project follows Swift best practices and uses SwiftLint for code style enforcement. Configuration can be found in `.swiftlint.yml`.

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
