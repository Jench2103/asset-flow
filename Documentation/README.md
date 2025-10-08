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

## Quick Start

**New to the project?** Read in this order:

1. [DevelopmentGuide.md](DevelopmentGuide.md) - Set up your environment
1. [Architecture.md](Architecture.md) - Understand the system design
1. [CodeStyle.md](CodeStyle.md) - Learn coding standards
1. [DataModel.md](DataModel.md) - Explore the data structures
1. [TestingStrategy.md](TestingStrategy.md) - Write quality tests

**Adding a feature?**

1. Review [Architecture.md](Architecture.md) for layer responsibilities
1. Check [DataModel.md](DataModel.md) if modifying data models
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

| Change                   | Update                                                                  |
| ------------------------ | ----------------------------------------------------------------------- |
| Add new model            | [DataModel.md](DataModel.md), `AssetFlow/Models/README.md`              |
| Change architecture      | [Architecture.md](Architecture.md)                                      |
| Add new tool/workflow    | [DevelopmentGuide.md](DevelopmentGuide.md)                              |
| Create coding convention | [CodeStyle.md](CodeStyle.md)                                            |
| Modify testing approach  | [TestingStrategy.md](TestingStrategy.md)                                |
| New build command        | [DevelopmentGuide.md](DevelopmentGuide.md), [`CLAUDE.md`](../CLAUDE.md) |

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

**Last Updated**: 2025-10-08

**Next Review**: When major architecture changes occur

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

| Document            | Status      | Coverage      | Last Updated |
| ------------------- | ----------- | ------------- | ------------ |
| Architecture.md     | ✅ Complete | Comprehensive | 2025-10-08   |
| DataModel.md        | ✅ Complete | Comprehensive | 2025-10-08   |
| DevelopmentGuide.md | ✅ Complete | Comprehensive | 2025-10-08   |
| CodeStyle.md        | ✅ Complete | Comprehensive | 2025-10-08   |
| TestingStrategy.md  | ✅ Complete | Comprehensive | 2025-10-08   |

______________________________________________________________________

Happy developing! 🚀
