# Data Models - Quick Reference

This directory contains the core SwiftData models for AssetFlow.

📖 **For comprehensive documentation, see [Documentation/DataModel.md](../../Documentation/DataModel.md)**

## Models Overview

### Asset

Individual investment or asset in a portfolio.

**Key Properties:**

- `name` - Display name
- `assetType` - Category (stock, bond, crypto, etc.)
- `currentValue` - Current market value
- `quantity` - Number of units held
- `currency` - Currency code (default: "USD")

**Relationships:**

- Portfolio (optional parent)
- Transactions (many children)

### Portfolio

Collection of assets grouped for organizational/strategic purposes.

**Key Properties:**

- `name` - Display name
- `targetAllocation` - Target percentages by asset type
- `isActive` - Active status

**Computed:**

- `totalValue` - Sum of all asset values

**Relationships:**

- Assets (many children)

### Transaction

Single financial transaction related to an asset.

**Key Properties:**

- `transactionType` - Type (buy, sell, dividend, etc.)
- `transactionDate` - When it occurred
- `quantity` - Units involved
- `pricePerUnit` - Price per unit
- `totalAmount` - Total transaction value

**Relationships:**

- Asset (optional parent)

### InvestmentPlan

Investment strategy or goal with defined parameters.

**Key Properties:**

- `name` - Plan name
- `targetAmount` - Goal amount
- `monthlyContribution` - Planned monthly investment
- `riskTolerance` - Risk level (veryLow to veryHigh)
- `status` - Current status (active, paused, completed, cancelled)

**Relationships:**

- Currently standalone (no relationships)

## Relationships

```
Portfolio (1:Many) → Asset (1:Many) → Transaction
```

Delete Rules:

- Portfolio → Assets: `.nullify` (assets remain when portfolio deleted)
- Asset → Transactions: `.cascade` (transactions deleted with asset)

## Critical Conventions

### Financial Data

⚠️ **Always use `Decimal` for monetary values** (never Float/Double)

```swift
var currentValue: Decimal  // ✅ Correct
var currentValue: Double   // ❌ Never do this
```

### Schema Registration

All models must be registered in `AssetFlowApp.swift`:

```swift
let schema = Schema([
    Asset.self,
    Portfolio.self,
    Transaction.self,
    InvestmentPlan.self
])
```

### When Adding/Modifying Models

1. Update the model file
1. Register in `AssetFlowApp.swift` Schema (if new)
1. Update this README
1. Update [Documentation/DataModel.md](../../Documentation/DataModel.md)
1. Consider migration strategy if changing existing models

## Quick Links

- 📐 [Architecture Documentation](../../Documentation/Architecture.md)
- 🗄️ [Complete Data Model Documentation](../../Documentation/DataModel.md)
- 🛠️ [Development Guide](../../Documentation/DevelopmentGuide.md)
- 🎨 [Code Style Guide](../../Documentation/CodeStyle.md)

## File Organization

```
Models/
├── README.md (this file)
├── Asset.swift
├── Portfolio.swift
├── Transaction.swift
└── InvestmentPlan.swift
```

______________________________________________________________________

For detailed information on:

- Complete property tables
- Enumerations (AssetType, TransactionType, RiskLevel, etc.)
- Computed properties
- Validation rules
- SwiftData configuration
- Migration strategies
- Usage examples

See the comprehensive [DataModel.md](../../Documentation/DataModel.md) documentation.
