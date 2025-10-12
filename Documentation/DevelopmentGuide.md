# Development Guide

## Getting Started

### Prerequisites

Before you begin development, ensure you have the following installed:

- **Xcode 15.0+** (with Command Line Tools)
- **macOS 14.0+** (for development)
- **Git** (for version control)
- **Homebrew** (recommended for tool installation)

### Required Tools

- **swift-format** - Code formatting
- **SwiftLint** - Code style enforcement
- **pre-commit** - Git hooks for automation

### Initial Setup

1. **Clone the Repository**

   ```bash
   git clone git@github.com:Jench2103/asset-flow-swift.git AssetFlow
   cd AssetFlow
   ```

1. **Open in Xcode**

   ```bash
   open AssetFlow.xcodeproj
   ```

1. **Install Development Tools**

   ```bash
   # Install formatting and linting tools
   brew install swift-format
   brew install swiftlint

   # Install pre-commit to automate checks
   brew install pre-commit
   pre-commit install
   ```

1. **Build the Project**

   - In Xcode: `⌘+B`
   - Command line: `xcodebuild -project AssetFlow.xcodeproj -scheme AssetFlow build`

1. **Run the Application**

   - In Xcode: `⌘+R`
   - Select target platform (macOS, iOS Simulator, iPad Simulator)

______________________________________________________________________

## Project Structure

```
AssetFlow/
├── AssetFlow/                  # Main application code
│   ├── Models/                 # SwiftData models
│   ├── Views/                  # SwiftUI views
│   ├── ViewModels/             # ViewModels (to be implemented)
│   ├── Services/               # Data services (to be implemented)
│   ├── Utilities/              # Helper functions and extensions
│   ├── Resources/              # Assets, localization
│   └── AssetFlowApp.swift      # App entry point
├── AssetFlow.xcodeproj/        # Xcode project
├── Documentation/              # Design documents (this folder)
├── .gitignore                  # Git ignore rules
├── .swiftlint.yml              # SwiftLint configuration
├── .swift-format               # swift-format configuration
├── .editorconfig               # Editor settings
├── .pre-commit-config.yaml     # Pre-commit hooks
├── CLAUDE.md                   # AI assistant instructions
└── README.md                   # Project overview
```

______________________________________________________________________

## Development Workflow

### 1. Creating a New Feature

**Branching Strategy**

```bash
# Create feature branch from main
git checkout main
git pull
git checkout -b feature/your-feature-name
```

**Implementation Steps**

1. Plan the feature (update models, views, services as needed)
1. Write code following style guidelines
1. Add tests (when testing framework is set up)
1. Test manually on all target platforms
1. Run linting and formatting
1. Commit with descriptive messages
1. Create pull request (if collaborating)

### 2. Code → Build → Test Cycle

**Development Cycle**

1. Make code changes
1. Run pre-commit checks (formatting, linting, etc.)
   ```bash
   pre-commit run --all-files
   ```
1. Build
   ```bash
   xcodebuild -project AssetFlow.xcodeproj -scheme AssetFlow build
   ```
1. Run tests (when available)
   ```bash
   xcodebuild test -project AssetFlow.xcodeproj -scheme AssetFlow
   ```
1. Run the app
   - Use Xcode or xcodebuild run

**Manual tool usage** (if needed):

```bash
# Format Swift code only
swift-format format --in-place --recursive --parallel .

# Format markdown only
pre-commit run mdformat --all-files

# Lint Swift code only
swiftlint
```

### 3. Pre-Commit Checks

Pre-commit hooks are configured in `.pre-commit-config.yaml` and automatically run on `git commit`:

**Automated Checks:**

- **Swift formatting**: Formats Swift code with swift-format
- **Swift linting**: Checks code style with SwiftLint
- **Markdown formatting**: Formats Markdown files with mdformat (120 char line wrap)
- **Trailing whitespace**: Removes trailing whitespace
- **Case conflicts**: Checks for case-sensitive filename conflicts
- **Merge conflicts**: Prevents committing merge conflict markers
- **JSON formatting**: Formats JSON files with 2-space indent

**Setup Pre-commit Hooks:**

```bash
# Install pre-commit (if not already installed)
brew install pre-commit

# Install hooks for this repository
pre-commit install

# Run hooks manually on all files
pre-commit run --all-files

# Run specific hook
pre-commit run mdformat --all-files
```

**Manual Override** (use sparingly):

```bash
git commit --no-verify -m "message"
```

### 4. Committing Changes

**Commit Message Format**

```
<type>: <subject>

<optional body>

<optional footer>
```

**Types**:

- `feat`: New feature
- `fix`: Bug fix
- `refactor`: Code refactoring
- `docs`: Documentation changes
- `style`: Code style changes (formatting)
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Example**:

```bash
git commit -m "feat: Add portfolio allocation chart view"
```

______________________________________________________________________

## Working with SwiftData

### Model Creation

1. **Create Model File**

   ```bash
   # Add new file in AssetFlow/Models/
   touch AssetFlow/Models/YourModel.swift
   ```

1. **Define Model**

   ```swift
   import SwiftData
   import Foundation

   @Model
   final class YourModel {
       var id: UUID
       var name: String

       init(name: String) {
           self.id = UUID()
           self.name = name
       }
   }
   ```

1. **Register in Schema** Update `AssetFlowApp.swift`:

   ```swift
   let schema = Schema([
       Asset.self,
       Portfolio.self,
       Transaction.self,
       InvestmentPlan.self,
       YourModel.self  // Add here
   ])
   ```

1. **Update Documentation**

   - Update `AssetFlow/Models/README.md`
   - Update `Documentation/DataModel.md`

### Querying Data

**In SwiftUI Views**:

```swift
@Query(sort: \YourModel.name)
private var items: [YourModel]
```

**With Predicates**:

```swift
@Query(filter: #Predicate<YourModel> { $0.isActive })
private var activeItems: [YourModel]
```

**Manual Context Access**:

```swift
@Environment(\.modelContext) private var modelContext

func addItem() {
    let item = YourModel(name: "Test")
    modelContext.insert(item)
    // Save is automatic
}
```

______________________________________________________________________

## Platform-Specific Development

### macOS Development

**Target**: macOS 14.0+

**Key Considerations**:

- Full keyboard navigation
- Window management
- Menu bar integration
- Toolbar items
- Multi-window support

**Platform Check**:

```swift
#if os(macOS)
.frame(minWidth: 800, minHeight: 600)
.toolbar {
    // macOS-specific toolbar items
}
#endif
```

### iOS Development

**Target**: iOS 17.0+

**Key Considerations**:

- Touch-first interface
- Navigation patterns (NavigationStack)
- Safe area handling
- Dynamic Type support
- Haptic feedback

**Platform Check**:

```swift
#if os(iOS)
.navigationBarTitleDisplayMode(.large)
.navigationBarItems(/* ... */)
#endif
```

### iPadOS Development

**Target**: iPadOS 17.0+

**Key Considerations**:

- Split view support
- Drag and drop
- Keyboard shortcuts
- Apple Pencil (if applicable)
- Size classes for adaptive layouts

**Platform Check**:

```swift
#if os(iOS)
.sheet(isPresented: $showDetail) {
    DetailView()
        .presentationDetents([.medium, .large])
}
#endif
```

### Testing on Simulators

```bash
# List available simulators
xcrun simctl list devices

# Boot specific simulator
xcrun simctl boot "iPhone 15 Pro"

# Run on specific simulator
xcodebuild test -project AssetFlow.xcodeproj \
  -scheme AssetFlow \
  -destination 'platform=iOS Simulator,name=iPhone 15 Pro'
```

______________________________________________________________________

## Code Formatting and Linting

This project uses two primary tools to ensure code quality, both of which are managed by pre-commit hooks.

### swift-format (for Formatting)

`swift-format` is used to automatically format all Swift code to a consistent style.

**Manual Commands**:

```bash
# Format all files in place
swift-format format --in-place --recursive --parallel .

# Check for formatting issues without making changes
swift-format lint --strict --recursive --parallel .
```

**Configuration**: The rules (indentation, line length, etc.) are defined in the `.swift-format` file.

### SwiftLint (for Linting)

`SwiftLint` is used to enforce a wide range of stylistic and convention-based rules that go beyond simple formatting. This includes rules for naming, complexity, and potential bugs.

**Manual Commands**:

```bash
# Lint all files and show warnings/errors
swiftlint

# Automatically correct lint violations where possible
swiftlint --fix
```

**Configuration**: The rules are defined in the `.swiftlint.yml` file. Key rules include:

- Sorted imports
- No force unwrapping (generates warning)
- No `print()` statements (use proper logging)
- Required file headers

______________________________________________________________________

## File Headers

**Required Format** (enforced by SwiftLint):

```swift
//
//  FileName.swift
//  AssetFlow
//
//  Created by [Your Name] on YYYY/MM/DD.
//
```

**Xcode Template**:

1. Xcode Preferences → Text Editing → File Header
1. Set custom header template

______________________________________________________________________

## Adding Dependencies

### Swift Package Manager

1. **Open Xcode** → File → Add Package Dependencies
1. Enter package URL
1. Select version/branch
1. Add to appropriate targets

**Example** (adding a chart library):

```swift
// In Package.swift (if using SPM standalone)
dependencies: [
    .package(url: "https://github.com/example/Charts.git", from: "1.0.0")
]
```

### CocoaPods / Carthage

**Not currently used** - Prefer Swift Package Manager for this project.

______________________________________________________________________

## Debugging

### Xcode Debugging

**Breakpoints**:

- Click gutter to add breakpoint
- Right-click for conditional breakpoints
- `po` command in LLDB console to print objects

**View Debugging**:

- Debug → View Debugging → Capture View Hierarchy
- Inspect SwiftUI view tree and layout

**Memory Graph**:

- Debug → Memory Graph
- Identify retain cycles

### Logging

**Recommended** (instead of `print()`):

```swift
import os.log

let logger = Logger(subsystem: "com.yourname.AssetFlow", category: "Portfolio")

logger.info("Portfolio loaded: \(portfolio.name)")
logger.error("Failed to save: \(error.localizedDescription)")
```

### SwiftData Debugging

**Enable SQL Logging**: Add launch argument in scheme:

```
-com.apple.CoreData.SQLDebug 1
```

______________________________________________________________________

## Building for Release

### Build Configuration

**Debug vs Release**:

- **Debug**: Full symbols, assertions enabled, slower
- **Release**: Optimized, symbols stripped, faster

### Archive for Distribution

1. **Xcode**: Product → Archive
1. Organizer opens with archive
1. Distribute App → Choose method
1. Follow platform-specific steps

### macOS Signing

- Developer ID application certificate
- Notarization required for distribution
- Hardened Runtime enabled

### iOS/iPadOS Signing

- App Store distribution certificate
- Provisioning profiles
- TestFlight for beta testing

______________________________________________________________________

## Troubleshooting

### Common Issues

**SwiftData not persisting**:

- Check ModelContainer is injected
- Verify schema registration
- Check for SwiftData errors in console

**UI not updating**:

- Ensure ViewModel uses `@Published`
- Verify View uses `@ObservedObject` or `@StateObject`
- Check `@Query` predicate

**Build failures**:

- Clean build folder: `⇧⌘K`
- Derived data: `~/Library/Developer/Xcode/DerivedData/`
- Restart Xcode

**Linting errors**:

- Run `swift-format format --in-place` before committing
- Check `.swiftlint.yml` for custom rules
- Add `// swiftlint:disable:next <rule>` for exceptions (use sparingly)

### Getting Help

- Check [CLAUDE.md](../CLAUDE.md) for project conventions
- Review [Architecture.md](Architecture.md) for design patterns
- Consult Apple's SwiftUI/SwiftData documentation
- Search existing code for similar patterns

______________________________________________________________________

## Code Review Checklist

Before submitting code for review:

- [ ] Code follows style guidelines
- [ ] File headers are correct
- [ ] No `print()` statements (use logging)
- [ ] SwiftLint passes without warnings
- [ ] swift-format applied
- [ ] Financial values use `Decimal` (not Float/Double)
- [ ] Platform-specific code uses `#if os()` properly
- [ ] Documentation updated (if applicable)
- [ ] Models registered in Schema (if new)
- [ ] Tested on all target platforms
- [ ] No force unwrapping without good reason
- [ ] Commit messages are descriptive

______________________________________________________________________

## Performance Best Practices

### SwiftUI

- Use `@State` for simple local state
- Use `@StateObject` for ViewModel ownership
- Minimize view body complexity
- Extract subviews for reusability
- Use `.task()` for async operations

### SwiftData

- Use predicates to filter queries
- Avoid loading entire relationship graphs
- Batch operations when possible
- Profile with Instruments

### Memory

- Weak references to avoid cycles
- Lazy initialization for heavy objects
- Release resources in deinit

______________________________________________________________________

## Continuous Integration (Future)

### GitHub Actions (Planned)

```yaml
# Example workflow
name: CI
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v2
      - name: Build
        run: xcodebuild build
      - name: Lint
        run: swiftlint
      - name: Test
        run: xcodebuild test
```

______________________________________________________________________

## Resources

### Documentation

- [Architecture.md](Architecture.md) - App architecture
- [DataModel.md](DataModel.md) - Data models
- [CodeStyle.md](CodeStyle.md) - Style guide
- [TestingStrategy.md](TestingStrategy.md) - Testing approach

### External Resources

- [Swift.org](https://swift.org/documentation/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata/)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

### Tools

- [SwiftLint](https://github.com/realm/SwiftLint)
- [swift-format](https://github.com/apple/swift-format)
- [SF Symbols](https://developer.apple.com/sf-symbols/) - Icon library

______________________________________________________________________

## Next Steps

Once you're familiar with the basics:

1. Review existing models in `AssetFlow/Models/`
1. Explore SwiftUI views in `AssetFlow/Views/`
1. Implement ViewModels in `AssetFlow/ViewModels/`
1. Build Services in `AssetFlow/Services/`
1. Add tests as you go
1. Contribute features incrementally

Happy coding! 🚀
