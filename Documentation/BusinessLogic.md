# Business Logic and Execution Design

## Preface

**Purpose of this Document**

This document describes the **business rules, calculations, workflows, and execution logic** that power AssetFlow's functionality. It focuses on the "what" and "how" of the application's behavior - what the system does with user data and how financial calculations, validations, and business processes are executed.

**What This Document Covers**

- **Business Rules**: Constraints, validations, and policies
- **Financial Calculations**: How values, returns, and allocations are computed
- **Data Workflows**: How data flows through create, read, update, delete operations
- **Transaction Processing**: Rules for handling financial transactions
- **Portfolio Management Logic**: Allocation, rebalancing, and aggregation
- **Investment Planning**: Goal tracking and recommendation logic

**What This Document Does NOT Cover**

- User interface design (see [UserInterfaceDesign.md](UserInterfaceDesign.md))
- Data model structure (see [DataModel.md](DataModel.md))
- System architecture (see [Architecture.md](Architecture.md))
- Testing strategies (see [TestingStrategy.md](TestingStrategy.md))

**Current Status**

🚧 **This document is a work in progress.** As business logic is implemented, this document will be updated to reflect actual rules, calculations, and workflows.

**Related Documentation**

- [DataModel.md](DataModel.md) - Data structures and relationships
- [Architecture.md](Architecture.md) - MVVM layer responsibilities

______________________________________________________________________

## Core Calculation Logic

### Asset State Calculation

An `Asset` has no stored state like quantity or value. Its state is always computed from its transaction and price history, ensuring data is always consistent.

**Current Quantity**

- **Logic**: Sum the `quantityImpact` of all `transactions` related to the asset.
- **Formula**: `Current Quantity = Σ (Transaction.quantityImpact)`

**Current Price**

- **Logic**: Find the most recent entry in the asset's `priceHistory`.
- **Rule**: When a user manually updates an asset's price, a new `PriceHistory` record is created.

**Current Value**

- **Formula**: `Current Value = Current Quantity * Current Price`

### Cost Basis and Gain/Loss

**Average Cost Method** (Phase 1)

- **Logic**: The average cost is calculated by dividing the total cost of all `buy` transactions by the total quantity acquired from those same transactions. This average cost per unit remains constant when shares are sold.
- **Formula**: `Average Cost = Σ(buy.totalAmount) / Σ(buy.quantity)`

**Cost Basis**

- **Logic**: The total cost basis for the *current* holdings.
- **Formula**: `Cost Basis = Current Quantity * Average Cost`

**Example: Cost Basis After a Sale**

1. **Buy 10 shares @ $10/share.**
   - Total Shares: 10
   - Average Cost: $10
   - Total Cost Basis: $100
1. **Buy 10 shares @ $12/share.**
   - Total Shares: 20
   - New Average Cost: ($100 + $120) / 20 shares = **$11/share**
   - Total Cost Basis: 20 * $11 = $220
1. **Sell 5 shares.**
   - The cost of the sold shares is `5 * $11 = $55`.
   - Remaining Shares: 15
   - The Average Cost per share **remains $11**.
   - **New Total Cost Basis**: 15 shares * $11/share = **$165**. The logic holds.

**Unrealized Gain/Loss**

- **Formula**: `Unrealized Gain = Current Value - Cost Basis`

**Realized Gain/Loss** (Phase 2+)

- **Logic**: Calculated when a `sell` transaction occurs.
- **Formula**: `Realized Gain = (Sell Quantity * Sell Price) - (Sell Quantity * Average Cost at time of sale)`

______________________________________________________________________

## Scalability: Real-Time Calculation vs. Snapshotting

A critical architectural decision is how to calculate an asset's state. Always calculating from the full transaction history guarantees accuracy but becomes slow with large datasets.

**Phase 1: Real-Time Calculation (MVP)**

- For the initial version of the application, all values (quantity, cost basis, etc.) will be calculated on-the-fly by iterating through the entire transaction and price history.
- **Pros**: Simple to implement, guarantees data integrity.
- **Cons**: Will not scale well for users with many years of transaction data.

**Phase 2 and Beyond: Performance Optimization via Snapshotting**

- To ensure high performance for historical charts and long-term users, a **snapshotting** mechanism will be implemented in a future phase.
- **Logic**: The app will periodically pre-calculate and store the state of an asset (e.g., quantity, cost basis) in an `AssetSnapshot` model. To get the current state, the app will load the latest snapshot and apply only the few transactions that have occurred since.
- **Benefit**: This provides near-instant access to both current and historical data points, enabling fast timeline views and ensuring the app remains responsive over time.

This phased approach allows for rapid initial development while establishing a clear, robust plan for future scalability.

______________________________________________________________________

## Transaction Processing Logic

### Transaction Types & Behavior

| Type          | Quantity Impact   | Description                                                                                                 |
| ------------- | ----------------- | ----------------------------------------------------------------------------------------------------------- |
| `buy`         | Positive          | A standard purchase of an asset. Increases quantity and cost basis.                                         |
| `sell`        | Negative          | A standard sale of an asset. Decreases quantity and realizes gains/losses.                                  |
| `transferIn`  | Positive          | Acquiring an asset without a direct purchase (e.g., moving from another brokerage). Often has a cost basis. |
| `transferOut` | Negative          | Moving an asset out without a sale.                                                                         |
| `adjustment`  | Positive/Negative | A manual correction to the quantity. Used for the "Set Quantity" feature. Price is typically zero.          |
| `dividend`    | Positive          | Income received from a `sourceAsset`. Typically affects a `cash` asset.                                     |
| `interest`    | Positive          | Interest received from a `sourceAsset`. Can affect a `cash` asset or be in-kind.                            |

### Special Transaction Workflows

**Asset Swap (e.g., sell BTC for ETH)**

1. A `sell` transaction is created for the source asset (BTC).
1. A `buy` transaction is created for the destination asset (ETH).
1. The two transactions are linked via their `relatedTransaction` relationship.

**Set Quantity**

1. User enters a new total quantity for an asset.
1. The app calculates the difference: `delta = newQuantity - currentQuantity`.
1. A new `adjustment` transaction is created with `quantity` equal to `delta`.

**Dividend/Interest Payment**

1. User records a dividend from a stock (e.g., AAPL) paid in cash.
1. An `dividend` transaction is created.
1. The `asset` for the transaction is the `Cash` asset (its quantity increases).
1. The `sourceAsset` for the transaction is the `AAPL` asset.

**In-Kind Interest (Staking Rewards)**

1. User records interest from a crypto asset (e.g., ETH) paid in-kind.
1. An `interest` transaction is created.
1. The `asset` for the transaction is the `ETH` asset itself.
1. The `sourceAsset` is also the `ETH` asset.

### Cash Transaction UI Logic

To provide a more intuitive user experience, the UI will display different labels for cash transactions.

- If `asset.assetType == .cash` and `transaction.type == .buy`, the UI will show **"Deposit"**.
- If `asset.assetType == .cash` and `transaction.type == .sell`, the UI will show **"Withdrawal"**.

This is a presentation-layer concern; the underlying data model remains consistent.

______________________________________________________________________

## Performance Tracking Logic

### Investment Return (Time-Weighted Return)

To accurately measure investment performance, we must remove the distorting effects of cash flows (e.g., adding or withdrawing money). The **Time-Weighted Rate of Return (TWR)** is the industry standard for this.

**Methodology**

The TWR calculation chains together the returns of multiple sub-periods. A new sub-period begins every time there is a cash flow or a significant price change.

1. **Identify Periods**: The start and end dates for each sub-period are determined by the dates of all `Transactions` and all `PriceHistory` entries for the asset.
1. **Calculate Period Return**: For each sub-period, calculate the simple holding period return:
   - `Return = (End Value - Start Value - Cash Flow) / Start Value`
   - `End Value` is the asset's value at the end of the sub-period.
   - `Start Value` is the asset's value at the start of the sub-period.
   - `Cash Flow` is the net amount of money invested or withdrawn during the period (from `buy`, `sell`, etc. transactions).
1. **Chain Returns**: Geometrically link the returns for each sub-period to get the final TWR.
   - `TWR = [(1 + Return_p1) * (1 + Return_p2) * ... * (1 + Return_pn)] - 1`

This method ensures that the calculated return reflects the performance of the investment choices, not the timing of deposits or withdrawals.

### Historical Value Timeline

- **Logic**: The timeline view is constructed by calculating an asset's value at each date where there is either a `Transaction` or a `PriceHistory` entry.
- **Data Points**: For any given date `D` on the chart:
  1. Calculate `Quantity at D` by summing all transactions up to and including `D`.
  1. Find `Price at D` by looking up the most recent `PriceHistory` entry on or before `D`.
  1. `Value at D = Quantity at D * Price at D`.

This provides the data needed to render a historical value chart.

______________________________________________________________________

## Portfolio Management Logic

### Portfolio Total Value

**Calculation**

**Formula**

```
Portfolio Total Value = Σ (Asset.currentValue) for all assets in portfolio
```

**Implementation**

- Computed property on the `Portfolio` model.
- Iterates through its `assets` relationship and sums the `currentValue` of each asset.

### Asset Allocation Calculation

**By Asset Type**

**Formula**

```
Allocation % = (Sum of asset values of type / Portfolio total value) × 100
```

**Implementation**

- Group assets by `assetType`.
- Sum values per type.
- Calculate percentage of total.

### Portfolio Deletion

**Business Rule**: Only empty portfolios (no assets) can be deleted.

**Validation Logic**:

1. Check `portfolio.isEmpty` computed property
1. If `true`, allow deletion
1. If `false`, prevent deletion and show error with asset count

**Deletion Workflow**:

1. User initiates deletion (context menu on macOS)
1. ViewModel validates portfolio is empty using `validateDeletion(of:)`
1. If valid, show confirmation dialog with portfolio name
1. If invalid, show error alert with asset count and recovery suggestion
1. On user confirmation, re-validate (edge case: state might have changed)
1. Execute deletion via `modelContext.delete(portfolio)`
1. SwiftData automatically removes portfolio (`.nullify` rule keeps assets intact)

**Error Scenarios**:

| Scenario                                   | Detection Point                          | User Feedback                        | Recovery Action                             |
| ------------------------------------------ | ---------------------------------------- | ------------------------------------ | ------------------------------------------- |
| Portfolio has assets                       | Initial validation in `initiateDelete()` | Error alert with asset count         | Remove all assets before deleting portfolio |
| Portfolio gains assets during confirmation | Re-validation in `confirmDelete()`       | Error alert with updated asset count | Cancel and remove assets                    |
| SwiftData deletion fails                   | Exception in `confirmDelete()`           | Error alert with system message      | Retry or restart application                |

**Implementation Details**:

- **File**: `AssetFlow/ViewModels/PortfolioManagementViewModel.swift`
- **Validation Method**: `validateDeletion(of:) -> Result<Void, PortfolioDeletionError>`
- **Initiation Method**: `initiateDelete(portfolio:)` - validates and sets UI state
- **Execution Method**: `confirmDelete()` - re-validates and deletes
- **Cancellation Method**: `cancelDelete()` - resets state without deletion
- **Error Type**: `PortfolioDeletionError` enum with localized messages

**Why `.nullify` Instead of `.deny`**:

SwiftData's `.deny` delete rule has known bugs (as of 2024-2025) and does not work reliably. Portfolio uses `.nullify` on the `assets` relationship, and business logic enforces deletion prevention by checking `portfolio.isEmpty` before allowing deletion.

______________________________________________________________________

## Investment Planning Logic

### Regular Saving Plan

**Goal**: To help users consistently invest by automating or reminding them of recurring investments.

**User-Defined Parameters**:

- **Plan Name**: A descriptive name for the saving plan (e.g., "Monthly S&P 500").
- **Asset**: The specific asset to be purchased (the "destination").
- **Source Asset**: The asset to use for payment (e.g., a "Cash" asset), or `nil` for external deposits.
- **Amount**: The amount of currency (e.g., "USD") to invest.
- **Frequency**: How often the investment should occur (e.g., daily, weekly, monthly).
- **Start Date**: The date the plan should begin.
- **Execution Method**:
  - `Automatic`: The application will automatically create a `buy` transaction on the scheduled date.
  - `Manual (Reminder)`: The application will notify the user to manually confirm and record the transaction.

**Execution Logic (Automatic)**:

1. A background service or scheduled task runs daily.
1. The service checks for all active `RegularSavingPlan`s where the next scheduled date is on or before the current date.
1. For each due plan:
   1. **If a `sourceAsset` is specified**:
      1. Create a `sell` transaction for the `sourceAsset`. The quantity of the `sourceAsset` to sell is determined by the `amount` of the plan. If the `sourceAsset` is cash, the quantity is the amount.
      1. Fetch the `pricePerUnit` for the destination `asset` from the configured price data source.
      1. Calculate the `quantity` to be purchased: `quantity = plan.amount / pricePerUnit`.
      1. Create a new `buy` transaction for the destination `asset` with the calculated quantity, price, and the scheduled date.
      1. Link the `buy` and `sell` transactions using the `relatedTransaction` property, creating a swap.
   1. **If `sourceAsset` is `nil`**:
      1. Fetch the `pricePerUnit` for the destination `asset`.
      1. Calculate the `quantity` to be purchased: `quantity = plan.amount / pricePerUnit`.
      1. Create a `transferIn` transaction for the destination `asset` with the calculated quantity and price. This represents acquiring an asset from an external source.
   1. Update the plan's `nextDueDate` based on its `frequency`.

**Execution Logic (Manual/Reminder)**:

1. A background service or scheduled task runs daily.
1. The service identifies all active plans due for a reminder.
1. It triggers a user notification (e.g., push notification on iOS, notification center on macOS).
1. The notification prompts the user to confirm the investment.
1. When the user acts on the notification, the app pre-fills the transaction creation screen with the plan's details (destination asset, source asset, amount). The user can then adjust the final price and quantity before saving.

**Validation Rules**:

- The selected `asset` must exist.
- If a `sourceAsset` is selected, it must exist and have a sufficient balance to cover the `amount`.
- The `amount` must be a positive value.
- The `frequency` must be a valid interval.

______________________________________________________________________

## Asset Deletion

**Business Rule**: Assets can be deleted at any time without restrictions.

**Deletion Workflow**:

1. User initiates deletion (right-click context menu on asset row)
1. Confirmation dialog shows asset name and warning
1. If user confirms, asset is deleted via `modelContext.delete(asset)`
1. SwiftData automatically cascades deletion to:
   - All `Transaction` records for the asset (`.cascade` rule)
   - All `PriceHistory` records for the asset (`.cascade` rule)
   - Removes asset from portfolio's `assets` relationship (`.nullify` rule)

**Error Handling**:

| Scenario              | Detection Point  | User Feedback                   | Recovery Action |
| --------------------- | ---------------- | ------------------------------- | --------------- |
| Deletion fails        | Exception        | Error alert with message        | Retry deletion  |
| Asset already deleted | Query after save | Asset no longer visible in list | Refresh view    |

**Implementation Details**:

- **File**: `AssetFlow/ViewModels/AssetManagementViewModel.swift`
- **Methods**: `initiateDelete(asset:)`, `confirmDelete()`, `cancelDelete()`
- **Error Type**: `AssetDeletionError` enum
- **UI**: Context menu on asset rows with confirmation dialog

______________________________________________________________________

## Data Validation Rules

### Asset Validation

- **Rule**: `name` must not be empty.
- **Rule**: `assetType` must be a valid enum case.

### Transaction Validation

- **Rule**: `quantity` and `pricePerUnit` must be non-negative.
- **Rule**: For a `sell` or `transferOut` transaction, the `quantity` must not exceed the asset's current holdings at the time of the transaction.
- **Rule**: `transactionDate` cannot be in the future.

### Portfolio Validation

- **Rule**: `name` must not be empty.
- **Rule**: If `targetAllocation` is set, the sum of its percentages should equal 100 (or a warning should be shown).

______________________________________________________________________

## References

### Financial Concepts

- [Investopedia - Cost Basis](https://www.investopedia.com/terms/c/costbasis.asp)
- [Investopedia - Time-Weighted Return](https://www.investopedia.com/terms/t/time-weightedror.asp)
- [Investopedia - Asset Allocation](https://www.investopedia.com/terms/a/assetallocation.asp)

### Calculation Libraries

- Swift `Decimal` type for precision
- Swift Charts for visualization
