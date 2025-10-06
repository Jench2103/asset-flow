# Data Models

This directory contains the core data models for AssetFlow, implemented using SwiftData for persistence across macOS, iOS, and iPadOS platforms.

## Overview

The data model is designed to track:
- Individual assets and their current values
- Portfolio organization and allocation strategies
- Transaction history for each asset
- Investment plans and goals

## Models

### Asset

Represents an individual investment or asset in a portfolio.

**Properties:**

- `id: UUID` - Unique identifier for the asset
- `name: String` - Display name of the asset (e.g., "Apple Inc.", "Bitcoin", "My Home")
- `assetType: AssetType` - Category of the asset (Stock, Bond, Crypto, Real Estate, etc.)
- `currentValue: Decimal` - Current market value of the total holdings
- `purchaseDate: Date` - Date when the asset was initially acquired
- `purchasePrice: Decimal?` - Original purchase price per unit (optional)
- `quantity: Decimal` - Number of units held (e.g., shares, coins, properties)
- `currency: String` - Currency code for values (default: "USD")
- `notes: String?` - Optional user notes or comments about the asset
- `lastUpdated: Date` - Timestamp of the last update to this asset

**Relationships:**

- `portfolio: Portfolio?` - The portfolio this asset belongs to
- `transactions: [Transaction]?` - All transactions associated with this asset

**Asset Types:**

- `stock` - Publicly traded stocks
- `bond` - Government or corporate bonds
- `crypto` - Cryptocurrencies
- `realEstate` - Real estate properties
- `commodity` - Gold, silver, oil, etc.
- `cash` - Cash holdings and savings
- `mutualFund` - Mutual fund investments
- `etf` - Exchange-traded funds
- `other` - Other asset types

### Portfolio

Represents a collection of assets grouped together for organizational or strategic purposes.

**Properties:**

- `id: UUID` - Unique identifier for the portfolio
- `name: String` - Display name (e.g., "Retirement Portfolio", "Emergency Fund")
- `portfolioDescription: String?` - Optional detailed description of the portfolio's purpose
- `createdDate: Date` - When this portfolio was created
- `targetAllocation: [String: Decimal]?` - Desired percentage allocation by asset type (e.g., {"Stock": 60, "Bond": 40})
- `isActive: Bool` - Whether this portfolio is currently active

**Relationships:**

- `assets: [Asset]?` - All assets contained in this portfolio

**Computed Properties:**

- `totalValue: Decimal` - Sum of all asset current values in the portfolio

### Transaction

Represents a single financial transaction related to an asset.

**Properties:**

- `id: UUID` - Unique identifier for the transaction
- `transactionType: TransactionType` - Type of transaction (Buy, Sell, Dividend, etc.)
- `transactionDate: Date` - When the transaction occurred
- `quantity: Decimal` - Number of units involved in the transaction
- `pricePerUnit: Decimal` - Price per unit at transaction time
- `totalAmount: Decimal` - Total transaction amount (quantity × pricePerUnit ± fees)
- `currency: String` - Currency code for the transaction (default: "USD")
- `fees: Decimal?` - Transaction fees or commissions (optional)
- `notes: String?` - Optional notes about the transaction

**Relationships:**

- `asset: Asset?` - The asset this transaction is associated with

**Transaction Types:**

- `buy` - Purchase of an asset
- `sell` - Sale of an asset
- `dividend` - Dividend payment received
- `interest` - Interest payment received
- `deposit` - Cash deposit
- `withdrawal` - Cash withdrawal
- `transfer` - Transfer between accounts

### InvestmentPlan

Represents an investment strategy or goal with defined parameters.

**Properties:**

- `id: UUID` - Unique identifier for the plan
- `name: String` - Display name (e.g., "Retirement by 2050", "House Down Payment")
- `planDescription: String?` - Detailed description of the plan's objectives
- `startDate: Date` - When the plan begins
- `endDate: Date?` - Target completion date (optional)
- `targetAmount: Decimal?` - Goal amount to reach (optional)
- `monthlyContribution: Decimal?` - Planned monthly investment amount (optional)
- `riskTolerance: RiskLevel` - Acceptable level of risk (Very Low to Very High)
- `status: PlanStatus` - Current status of the plan (Active, Paused, Completed, Cancelled)
- `notes: String?` - Additional notes or strategy details
- `createdDate: Date` - When this plan was created
- `lastUpdated: Date` - Last modification timestamp

**Risk Levels:**

- `veryLow` - Minimal risk tolerance (conservative)
- `low` - Low risk tolerance
- `moderate` - Balanced risk tolerance
- `high` - High risk tolerance
- `veryHigh` - Maximum risk tolerance (aggressive)

**Plan Status:**

- `active` - Currently being followed
- `paused` - Temporarily suspended
- `completed` - Goal achieved
- `cancelled` - No longer pursuing

## Relationships

```
Portfolio (1) ──< (Many) Asset (1) ──< (Many) Transaction
```

- A Portfolio can contain many Assets
- An Asset belongs to one Portfolio (or none)
- An Asset can have many Transactions
- A Transaction belongs to one Asset

InvestmentPlan is currently independent but can be extended to link with Portfolios in future iterations.

## Data Precision

All monetary values use `Decimal` type to ensure precision in financial calculations, avoiding floating-point rounding errors.

## Future Enhancements

Potential additions to the data model:

- Performance metrics and analytics
- Historical value tracking (snapshots over time)
- Multi-currency portfolio support with exchange rates
- Asset categorization tags
- Benchmark comparisons
- Tax lot tracking for capital gains
- Integration with external data sources
