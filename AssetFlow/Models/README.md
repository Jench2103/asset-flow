# Data Models - Quick Reference

This directory contains the core SwiftData models for AssetFlow.

📖 **For comprehensive documentation, see [Documentation/DataModel.md](../../Documentation/DataModel.md)**

## Models Overview

### Asset

Individual investment or asset in a portfolio. Defined by its transactions and price history; holds minimal state.

**Key Properties:**

- `name` - Display name
- `assetType` - Category (stock, bond, crypto, etc.)
- `currency` - Currency code (default: "USD")
- `notes` - Optional user notes

**Computed Properties:**

- `quantity` - Calculated from transactions
- `currentPrice` - Most recent price from price history
- `currentValue` - Quantity × current price
- `averageCost` - Average cost per unit from buy transactions
- `costBasis` - Total cost basis for current holdings

**Relationships:**

- Portfolio (optional parent, `.nullify`)
- Transactions (many children, `.cascade`)
- PriceHistory (many children, `.cascade`)

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

- `transactionType` - Type (buy, sell, transferIn, transferOut, adjustment, dividend, interest)
- `transactionDate` - When it occurred
- `quantity` - Units involved
- `pricePerUnit` - Price per unit
- `totalAmount` - Total transaction value
- `currency` - Currency code
- `fees` - Optional transaction fees

**Computed Properties:**

- `quantityImpact` - Impact on asset quantity (negative for sell/transferOut)

**Relationships:**

- `asset` - The asset whose quantity is changing (`.nullify`)
- `sourceAsset` - Asset generating income (for dividends/interest)
- `relatedTransaction` - Linked transaction for swaps

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

### PriceHistory

Represents the price of an asset at a specific point in time.

**Key Properties:**

- `date` - When the price was recorded
- `price` - The price of one unit of the asset

**Relationships:**

- `asset` - The parent asset (`.nullify`)

### RegularSavingPlan

Represents a recurring investment plan for automated or reminder-based savings.

**Key Properties:**

- `name` - Plan name
- `amount` - Investment amount per occurrence
- `frequency` - How often to invest (daily, weekly, biweekly, monthly)
- `startDate` - When the plan begins
- `nextDueDate` - Next scheduled investment date
- `executionMethod` - Automatic or manual execution
- `isActive` - Active status

**Relationships:**

- `asset` - The asset to purchase (`.nullify`)
- `sourceAsset` - The asset to withdraw from (`.nullify`, optional)

## Relationships

```
Portfolio (1:Many) → Asset (1:Many) → Transaction
                     Asset (1:Many) → PriceHistory
                     Transaction → sourceAsset (Asset)
                     Transaction → relatedTransaction (self)
RegularSavingPlan (1:1) → asset (Asset)
RegularSavingPlan (1:1) → sourceAsset (Asset)
InvestmentPlan (standalone)
```

Delete Rules:

- Portfolio → Assets: `.nullify` (assets remain, portfolio ref set to nil; **business logic must prevent deletion of non-empty portfolios**)
- Asset → Transactions: `.cascade` (transactions deleted with asset)
- Asset → PriceHistory: `.cascade` (price history deleted with asset)
- Transaction → Asset: (no delete rule, default behavior)
- RegularSavingPlan → Asset: `.nullify` (asset reference set to nil when asset deleted)

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
    InvestmentPlan.self,
    PriceHistory.self,
    RegularSavingPlan.self,
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
├── InvestmentPlan.swift
├── PriceHistory.swift
└── RegularSavingPlan.swift
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
