# AssetFlow Documentation

Welcome to the AssetFlow project documentation. This folder contains comprehensive design documents and guides for developing and maintaining the AssetFlow application.

## Documentation Index

### 📐 [Architecture.md](Architecture.md)

**System design and architectural patterns**

Learn about:

- MVVM architecture pattern
- Layer responsibilities (View, ViewModel, Model, Service)
- Data flow and state management
- SwiftData integration
- Multi-platform strategy (macOS, iOS, iPadOS)
- Dependency management
- Future architecture enhancements

**Who should read**: All developers working on AssetFlow

______________________________________________________________________

### 🗄️ [DataModel.md](DataModel.md)

**Complete data model reference**

Covers:

- Core entities: Asset, Portfolio, Transaction, InvestmentPlan
- Property definitions and types
- Relationships and delete rules
- SwiftData configuration
- Financial data precision with Decimal
- Data validation rules
- Schema migration strategy

**Who should read**: Developers working with data models, backend integration, or business logic

______________________________________________________________________

### 🛠️ [DevelopmentGuide.md](DevelopmentGuide.md)

**Getting started and development workflow**

Includes:

- Project setup and prerequisites
- Development environment configuration
- Build commands and workflows
- Working with SwiftData
- Platform-specific development (macOS/iOS/iPadOS)
- Code formatting and linting
- Debugging tips and troubleshooting
- Code review checklist

**Who should read**: New contributors, developers setting up their environment

______________________________________________________________________

### 🎨 [CodeStyle.md](CodeStyle.md)

**Coding standards and conventions**

Details:

- Naming conventions
- Code formatting rules
- SwiftUI-specific patterns
- SwiftData best practices
- Financial data handling (Decimal usage)
- Platform-specific code organization
- Documentation standards
- Logging guidelines (no `print()` statements!)

**Who should read**: All developers to maintain code consistency

______________________________________________________________________

### 🧪 [TestingStrategy.md](TestingStrategy.md)

**Comprehensive testing approach**

Explains:

- Testing philosophy and pyramid
- Unit testing with Swift Testing
- Integration testing with SwiftData
- UI testing for critical flows
- Mocking and test doubles
- Test coverage goals
- Performance testing
- Manual testing checklist

**Who should read**: Developers writing tests, QA engineers, CI/CD maintainers

______________________________________________________________________

### 🎯 [UserInterfaceDesign.md](UserInterfaceDesign.md)

**User interface and interaction design**

Documents:

- Development phases and UI priorities
- Screen layouts and user flows
- Visual style (colors, typography, icons)
- Navigation patterns (macOS, iOS, iPadOS)
- Component library and design patterns
- Platform-specific adaptations
- Accessibility considerations
- SwiftUI implementation guidance

**Who should read**: Developers building UI, designers, anyone working on user experience

______________________________________________________________________

### ⚙️ [BusinessLogic.md](BusinessLogic.md)

**Business rules and execution logic**

Covers:

- Financial calculations (cost basis, gain/loss, allocations)
- Transaction processing and validation rules
- Portfolio management logic
- Investment plan tracking algorithms
- Data workflows (CRUD operations)
- State management patterns
- Edge cases and error handling
- Calculation examples and formulas

**Who should read**: Developers implementing business logic, QA engineers verifying calculations

______________________________________________________________________

### 🔒 [SecurityAndPrivacy.md](SecurityAndPrivacy.md)

**Security and privacy considerations**

Details:

- Threat model and risk assessment
- Data security (encryption, storage, backups)
- Privacy principles (data collection, usage, control)
- Platform security features (sandbox, keychain, etc.)
- Secure coding practices
- Compliance considerations (GDPR, CCPA)
- User security best practices
- Incident response procedures

**Who should read**: All developers, security-conscious contributors, privacy advocates

______________________________________________________________________

### 🔌 [APIDesign.md](APIDesign.md)

**API and integration design**

Describes:

- External API integrations (price data, market info)
- Internal API patterns (services, ViewModels)
- Data import/export formats (CSV, JSON)
- API error handling and rate limiting
- Caching strategies
- Future integration plans (iCloud sync, brokerage connections)
- Testing API interactions
- Privacy considerations for external APIs

**Who should read**: Developers working on integrations, API consumers, backend integration

______________________________________________________________________

## Quick Start

**New to the project?** Read in this order:

1. [DevelopmentGuide.md](DevelopmentGuide.md) - Set up your environment
1. [Architecture.md](Architecture.md) - Understand the system design
1. [CodeStyle.md](CodeStyle.md) - Learn coding standards
1. [DataModel.md](DataModel.md) - Explore the data structures
1. [TestingStrategy.md](TestingStrategy.md) - Write quality tests

**Designing a feature?**

1. Review [UserInterfaceDesign.md](UserInterfaceDesign.md) for UI patterns and screen layouts
1. Check [BusinessLogic.md](BusinessLogic.md) for business rules and calculations
1. Consider [SecurityAndPrivacy.md](SecurityAndPrivacy.md) if handling sensitive data
1. Plan [APIDesign.md](APIDesign.md) if integrating external services

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
| API integration            | [APIDesign.md](APIDesign.md)                                                                 |
| Major feature (all design) | [UserInterfaceDesign.md](UserInterfaceDesign.md), [BusinessLogic.md](BusinessLogic.md), etc. |

**Documentation is code** - keep it accurate, clear, and up-to-date!

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
git commit -m "docs: Update DataModel.md with new InvestmentPlan fields"
```

______________________________________________________________________

## Document Maintenance

**Last Updated**: 2025-10-09

**Next Review**: When major architecture or design changes occur

**Maintainers**: Project contributors

______________________________________________________________________

## Questions?

If something is unclear or missing from the documentation:

1. Check the specific document's table of contents
1. Search for keywords across all documentation files
1. Review the project's [`CLAUDE.md`](../CLAUDE.md) for conventions
1. Consult the team or create an issue

______________________________________________________________________

## Document Status

| Document               | Status       | Coverage      | Last Updated |
| ---------------------- | ------------ | ------------- | ------------ |
| Architecture.md        | ✅ Complete  | Comprehensive | 2025-10-08   |
| DataModel.md           | ✅ Complete  | Comprehensive | 2025-10-08   |
| DevelopmentGuide.md    | ✅ Complete  | Comprehensive | 2025-10-09   |
| CodeStyle.md           | ✅ Complete  | Comprehensive | 2025-10-08   |
| TestingStrategy.md     | ✅ Complete  | Comprehensive | 2025-10-08   |
| UserInterfaceDesign.md | 🚧 Framework | Initial       | 2025-10-09   |
| BusinessLogic.md       | 🚧 Framework | Initial       | 2025-10-09   |
| SecurityAndPrivacy.md  | ✅ Complete  | Comprehensive | 2025-10-09   |
| APIDesign.md           | 🚧 Framework | Initial       | 2025-10-09   |

**Legend:**

- ✅ Complete: Comprehensive documentation, updated regularly
- 🚧 Framework: Structure established, content to be filled as features develop

______________________________________________________________________

Happy developing! 🚀
