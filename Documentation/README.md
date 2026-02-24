# AssetFlow Documentation

Welcome to the AssetFlow project documentation. This folder contains comprehensive design documents and guides for developing and maintaining the AssetFlow application -- a macOS desktop application for snapshot-based portfolio management and asset allocation tracking.

## Documentation Index

### [SPEC.md](SPEC.md)

**Product and technical specification (v1.3)**

The foundational requirements document defining what AssetFlow does:

- Core concept: snapshot-based portfolio model
- User interface design and navigation
- CSV import system and validation rules
- Data model (Category, Asset, Snapshot, SnapshotAssetValue, CashFlowOperation, ExchangeRate)
- Calculation logic (growth rate, Modified Dietz, TWR, CAGR)
- Rebalancing engine, visualizations, error handling
- Architecture requirements and non-goals

**Who should read**: Everyone — this is the source of truth for all design decisions

______________________________________________________________________

### [Architecture.md](Architecture.md)

**System design and architectural patterns**

Learn about:

- MVVM architecture pattern
- Layer responsibilities (View, ViewModel, Model, Service)
- Data flow and state management
- SwiftData integration
- macOS-only platform design
- Dependency management

**Who should read**: All developers working on AssetFlow

______________________________________________________________________

### [DataModel.md](DataModel.md)

**Complete data model reference**

Covers:

- Core entities: Category, Asset, Snapshot, SnapshotAssetValue, CashFlowOperation
- Property definitions and types
- Relationships and delete rules
- Uniqueness constraints
- SwiftData configuration
- Financial data precision with Decimal
- Data validation rules
- Schema migration strategy

**Who should read**: Developers working with data models or business logic

______________________________________________________________________

### [DevelopmentGuide.md](DevelopmentGuide.md)

**Getting started and development workflow**

Includes:

- Project setup and prerequisites
- Development environment configuration
- Build commands and workflows
- Working with SwiftData
- macOS-specific development
- Code formatting and linting
- Localization workflow
- Debugging tips and troubleshooting
- Code review checklist

**Who should read**: New contributors, developers setting up their environment

______________________________________________________________________

### [CodeStyle.md](CodeStyle.md)

**Coding standards and conventions**

Details:

- Naming conventions
- Code formatting rules
- SwiftUI-specific patterns
- SwiftData best practices
- Financial data handling (Decimal usage)
- macOS-specific code patterns
- Documentation standards
- Logging guidelines (no `print()` statements)

**Who should read**: All developers to maintain code consistency

______________________________________________________________________

### [TestingStrategy.md](TestingStrategy.md)

**Comprehensive testing approach**

Explains:

- Testing philosophy and pyramid
- Unit testing with Swift Testing
- Integration testing with SwiftData
- Mocking and test doubles
- Test coverage goals
- Test examples for new models and ViewModels

**Who should read**: Developers writing tests, QA engineers, CI/CD maintainers

______________________________________________________________________

### [UserInterfaceDesign.md](UserInterfaceDesign.md)

**User interface and interaction design**

Documents:

- Sidebar navigation structure (Dashboard, Snapshots, Assets, Categories, Platforms, Rebalancing, Import)
- Screen layouts and user flows
- List-detail split patterns
- Visual style (colors, typography, icons)
- Chart specifications (pie, line, TWR)
- Empty states and edge cases
- Settings and data management
- Accessibility considerations

**Who should read**: Developers building UI, designers, anyone working on user experience

______________________________________________________________________

### [BusinessLogic.md](BusinessLogic.md)

**Business rules and calculation logic**

Covers:

- Snapshot-based portfolio model
- Portfolio value calculation
- Category allocation and rebalancing engine
- Growth rate calculation
- Modified Dietz return calculation
- Cumulative TWR and CAGR
- CSV import validation and duplicate detection
- Asset identity and matching rules
- Edge cases and error handling

**Who should read**: Developers implementing business logic, QA engineers verifying calculations

______________________________________________________________________

### [SecurityAndPrivacy.md](SecurityAndPrivacy.md)

**Security and privacy considerations**

Details:

- Local-only architecture (no network, no API keys)
- Data security (SwiftData, file system encryption)
- Backup file security (ZIP export/restore)
- Privacy principles (no data collection, no telemetry)
- macOS platform security features (sandbox, hardened runtime)
- Secure coding practices
- Compliance considerations (GDPR, CCPA)

**Who should read**: All developers, security-conscious contributors

______________________________________________________________________

### [APIDesign.md](APIDesign.md)

**Internal API and integration design**

Describes:

- Internal service APIs (CSV parsing, backup/restore)
- ViewModel contracts and data access patterns
- CSV import/export format specifications
- Backup archive format (ZIP with CSV files and manifest)
- Error handling patterns
- No external API integrations (local-only)

**Who should read**: Developers working on services, import/export, or data management

______________________________________________________________________

## Quick Start

**New to the project?** Read in this order:

1. [SPEC.md](SPEC.md) - Understand the product requirements
1. [DevelopmentGuide.md](DevelopmentGuide.md) - Set up your environment
1. [Architecture.md](Architecture.md) - Understand the system design
1. [CodeStyle.md](CodeStyle.md) - Learn coding standards
1. [DataModel.md](DataModel.md) - Explore the data structures
1. [TestingStrategy.md](TestingStrategy.md) - Write quality tests

**Designing a feature?**

1. Review [UserInterfaceDesign.md](UserInterfaceDesign.md) for UI patterns and screen layouts
1. Check [BusinessLogic.md](BusinessLogic.md) for business rules and calculations
1. Consider [SecurityAndPrivacy.md](SecurityAndPrivacy.md) if handling sensitive data
1. Plan [APIDesign.md](APIDesign.md) for internal service interfaces

**Implementing a feature?**

1. Review [Architecture.md](Architecture.md) for layer responsibilities
1. Check [DataModel.md](DataModel.md) if modifying data models
1. Reference [UserInterfaceDesign.md](UserInterfaceDesign.md) for UI implementation
1. Implement logic from [BusinessLogic.md](BusinessLogic.md)
1. Follow [CodeStyle.md](CodeStyle.md) for implementation
1. Reference [TestingStrategy.md](TestingStrategy.md) for test coverage

**Fixing a bug?**

1. Write a failing test first ([TestingStrategy.md](TestingStrategy.md))
1. Follow debugging tips in [DevelopmentGuide.md](DevelopmentGuide.md)
1. Ensure code style compliance ([CodeStyle.md](CodeStyle.md))
1. Verify fix doesn't break architecture ([Architecture.md](Architecture.md))

______________________________________________________________________

## Additional Resources

### Project Files

- [`README.md`](../README.md) - Project overview
- [`CLAUDE.md`](../CLAUDE.md) - AI assistant guidance
- [`AssetFlow/Models/README.md`](../AssetFlow/Models/README.md) - Model documentation

### Configuration Files

- [`.swiftlint.yml`](../.swiftlint.yml) - Linting rules
- [`.swift-format`](../.swift-format) - Formatting configuration
- [`.editorconfig`](../.editorconfig) - Editor settings
- [`.pre-commit-config.yaml`](../.pre-commit-config.yaml) - Git hooks

### External Links

- [Swift Documentation](https://swift.org/documentation/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [SwiftData Documentation](https://developer.apple.com/documentation/swiftdata/)
- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)

______________________________________________________________________

## Keeping Documentation Updated

**When to update documentation:**

| Change                     | Update                                                                                       |
| -------------------------- | -------------------------------------------------------------------------------------------- |
| Add new model              | [DataModel.md](DataModel.md), `AssetFlow/Models/README.md`                                   |
| Change architecture        | [Architecture.md](Architecture.md)                                                           |
| Add new tool/workflow      | [DevelopmentGuide.md](DevelopmentGuide.md)                                                   |
| Create coding convention   | [CodeStyle.md](CodeStyle.md)                                                                 |
| Modify testing approach    | [TestingStrategy.md](TestingStrategy.md)                                                     |
| New build command          | [DevelopmentGuide.md](DevelopmentGuide.md), [`CLAUDE.md`](../CLAUDE.md)                      |
| Design new screen/UI       | [UserInterfaceDesign.md](UserInterfaceDesign.md)                                             |
| Add business rule/calc     | [BusinessLogic.md](BusinessLogic.md)                                                         |
| Security/privacy change    | [SecurityAndPrivacy.md](SecurityAndPrivacy.md)                                               |
| API/service integration    | [APIDesign.md](APIDesign.md)                                                                 |
| Major feature (all design) | [UserInterfaceDesign.md](UserInterfaceDesign.md), [BusinessLogic.md](BusinessLogic.md), etc. |

**Documentation is code** -- keep it accurate, clear, and up-to-date!

______________________________________________________________________

## Contributing to Documentation

Found an error or unclear explanation?

1. Check if it's already documented elsewhere
1. Update the relevant document
1. Ensure consistency across all docs
1. Update this README if adding new sections
1. Submit changes with descriptive commit message

**Example commit**:

```bash
git commit -m "docs: Update DataModel.md with new SnapshotAssetValue fields"
```

______________________________________________________________________

## Document Status

| Document               | Status  |
| ---------------------- | ------- |
| SPEC.md                | Current |
| Architecture.md        | Current |
| DataModel.md           | Current |
| DevelopmentGuide.md    | Current |
| CodeStyle.md           | Current |
| TestingStrategy.md     | Current |
| UserInterfaceDesign.md | Current |
| BusinessLogic.md       | Current |
| SecurityAndPrivacy.md  | Current |
| APIDesign.md           | Current |
