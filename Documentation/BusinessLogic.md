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

## Asset Creation Logic

### Initial Position Setup

When creating a new non-cash asset, the user provides two price-related fields:

1. **Cost Basis** (required): The price paid per unit. This is used as the `pricePerUnit` on the initial `buy` transaction.
1. **Current Price** (optional): The current market price per unit. This is used as the `price` on the initial `PriceHistory` record.

If the user leaves the current price empty, the cost basis value is used for the initial price history record (i.e., assuming the current market price equals what was paid).

For **cash assets**, both the transaction price and price history are always set to 1, regardless of user input.

**Example**: A user bought 10 shares of AAPL at $100/share, but the current market price is $120/share.

- Cost Basis = 100 → Transaction: `pricePerUnit = 100`, `totalAmount = 1000`
- Current Price = 120 → PriceHistory: `price = 120`
- The asset's `currentValue` = 10 * 120 = $1,200

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

### Transaction CRUD Operations

**Implementation Status**: ✅ Implemented (Create, Read, Update, Delete)

**Implementation Files**:

- **Form ViewModel**: `AssetFlow/ViewModels/TransactionFormViewModel.swift` — create/edit form validation and save logic
- **Management ViewModel**: `AssetFlow/ViewModels/TransactionManagementViewModel.swift` — deletion flow and list state
- **Form View**: `AssetFlow/Views/TransactionFormView.swift` — record/edit transaction form
- **History View**: `AssetFlow/Views/TransactionHistoryView.swift` — transaction history modal with context menu actions
- **Asset Detail**: `AssetFlow/Views/AssetDetailView.swift` — buttons to access transaction features
- **Tests**: `AssetFlowTests/TransactionFormViewModelTests.swift`, `AssetFlowTests/TransactionManagementViewModelTests.swift`

### Transaction Creation Workflow

**Form Validation Rules**:

1. **Date**: Cannot be in the future. Validated against start of day to allow any time on the current day.
1. **Quantity / Amount**: Required, must be a valid positive number greater than zero. For sell/transferOut transactions, quantity cannot exceed current asset holdings. Labeled "Amount" for cash assets, "Quantity" for others.
1. **Price per Unit**: Required for non-cash assets, must be a valid number >= 0. Zero is allowed for free transfers. Pre-filled with the asset's current price from price history. For cash assets, price is always fixed at 1 (field is hidden from the UI and validation is skipped).

**Sell/TransferOut Quantity Cap**:

- Before saving a sell or transferOut transaction, the form validates that `quantity <= asset.quantity`
- `asset.quantity` is computed as the sum of all transaction quantity impacts
- If validation fails, an error message shows: "Cannot sell more than current holdings (N)" or "Cannot transfer out more than current holdings (N)"
- Changing the transaction type re-validates the quantity to catch transitions between buy/sell

**Auto-Calculated Total Amount**:

- `totalAmount = quantity × pricePerUnit`
- Displayed as a read-only field in the form
- Shows "—" if either input is invalid or empty
- Stored on the Transaction record for historical accuracy

**Cash-Friendly Label Mapping**:

- When `asset.assetType == .cash`:
  - `buy` → displayed as "Deposit"
  - `sell` → displayed as "Withdrawal"
- All other transaction types retain their standard labels
- This is a presentation-layer concern; the underlying data model uses `.buy`/`.sell`

**Asset Quantity Auto-Update**:

- Asset quantity is a computed property: `Σ (Transaction.quantityImpact)`
- No manual update needed — saving a new transaction automatically changes the asset's quantity
- Buy/transferIn/adjustment/dividend/interest increase quantity
- Sell/transferOut decrease quantity

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

### Transaction Edit Workflow

**Implementation Status**: ✅ Implemented

1. User selects "Edit" on a transaction entry (context menu)
1. Form pre-populates with existing transaction data (type, date, quantity, price)
1. All interaction flags set to `true` so validation messages show immediately
1. User modifies any fields

**Edit Validation Rules**:

- Same base validation as creation (date not in future, quantity > 0, price >= 0)
- **Resulting quantity check**: The asset's quantity after the edit must remain >= 0
  - Formula: `baseQuantity + newImpact >= 0`
  - Where `baseQuantity = asset.quantity - existingTransaction.quantityImpact`
  - Where `newImpact` is the quantity impact of the edited transaction values
- This covers type changes (e.g., buy → sell), quantity changes, and all edge cases
- Cash assets: price per unit stays locked at 1 in edit mode (same as create)

**Save Behavior**:

- Updates the existing `Transaction` record in-place (no new insert)
- Transaction count remains unchanged
- Asset quantity recalculates automatically via computed property

### Transaction Delete Workflow

**Implementation Status**: ✅ Implemented

**Delete Validation**:

- Before allowing deletion, check if removing the transaction would cause negative quantity
- Constraint: `(asset.quantity - transaction.quantityImpact) >= 0`
- Removing a buy/transferIn/dividend/interest transaction decreases the asset's quantity
- Removing a sell/transferOut transaction increases the asset's quantity

**If validation passes (quantity remains valid)**:

1. User selects "Delete" on a transaction entry (context menu)
1. Confirmation dialog appears showing transaction type and date
1. On confirmation:
   - Deletes `Transaction` record from SwiftData
   - Asset quantity recalculates automatically
   - All dependent calculations update accordingly

**If validation fails (would cause negative quantity)**:

1. User selects "Delete" on a transaction entry (context menu)
1. Error alert appears: "Cannot Delete Transaction"
1. Message: "Deleting this transaction would cause the asset quantity to become negative."
1. Recovery suggestion: "Delete or edit other transactions first to ensure the quantity remains valid."

**Cascading delete (when asset is deleted)**:

- All associated `Transaction` records deleted automatically via `.cascade` rule
- Asset deletion has no transaction-level validation (entire asset is removed)

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

## Asset Type and Currency Immutability

**Business Rule**: Once an asset has associated transactions or price history, its type and currency cannot be edited.

**Rationale**:

- **Data Integrity**: Asset type defines the nature of the investment. Changing it retroactively would misrepresent historical records.
- **Currency Consistency**: Prices and transaction amounts are denominated in the asset's currency. Changing it would break historical calculations (cost basis, gains/losses).
- **Audit Trail**: Users can see exactly what they purchased and in what currency, creating a clear audit trail.

**Implementation**:

- Asset has `isLocked` computed property that returns `true` if `transactions.isEmpty == false || priceHistory.isEmpty == false`
- When editing an asset, `canEditAssetType` and `canEditCurrency` return `false` if the asset is locked
- UI disables the Type and Currency pickers and shows explanatory text when fields are locked
- New assets (before any transactions or price history) allow editing these fields

**Recovery Options for Users**:

If a user makes a mistake during asset creation:

1. **Before saving**: User can change type/currency freely during initial creation
1. **After saving**: User must delete the asset and recreate it with the correct type/currency

This design prevents accidental changes to asset metadata while providing clear recovery options at the appropriate time.

______________________________________________________________________

## Price History Management

**Implementation Status**: ✅ Implemented

**Implementation Files**:

- **Form ViewModel**: `AssetFlow/ViewModels/PriceHistoryFormViewModel.swift` — add/edit form with validation
- **Management ViewModel**: `AssetFlow/ViewModels/PriceHistoryManagementViewModel.swift` — deletion flow
- **Form View**: `AssetFlow/Views/PriceHistoryFormView.swift` — add/edit price record form
- **List View**: `AssetFlow/Views/PriceHistoryView.swift` — price history modal with macOS Table
- **Asset Detail**: `AssetFlow/Views/AssetDetailView.swift` — shows current price + date, link to price history
- **Model**: `AssetFlow/Models/Asset.swift` — `currentPriceDate` computed property
- **Tests**: `AssetFlowTests/PriceHistoryFormViewModelTests.swift` (22 tests), `AssetFlowTests/PriceHistoryManagementViewModelTests.swift` (16 tests), `AssetFlowTests/AssetIntegrationTests.swift` (3 additional tests)

### Price History CRUD Operations

**Create Price Record**

1. User opens price history modal/sheet for an asset
1. Clicks "Add Price Record" button
1. Fills in date (defaults to today) and price
1. Validates:
   - Date cannot be in the future
   - Date cannot duplicate an existing price record for this asset
   - Price must be a positive number (>= 0)
1. On save:
   - Creates new `PriceHistory` record linked to asset
   - Persists to SwiftData automatically
   - If this is the only/latest price, `Asset.currentPrice` updates
   - All dependent calculations (current value, gains/losses) recalculate

**Read Price History**

1. Asset's `priceHistory` relationship contains all price records
1. `Asset.currentPrice` computed property retrieves the most recent price:
   ```swift
   priceHistory?.sorted(by: { $0.date > $1.date }).first?.price ?? 0
   ```
1. Price history displayed in chronological order (newest first)
1. `Asset.currentPriceDate` computed property returns date of latest price

**Update Price Record**

1. User selects "Edit" on a price history entry
1. Form pre-populates with existing date and price
1. User modifies date and/or price
1. Validation:
   - Same date validation as "Create"
   - **When changing date**: Ensure new date doesn't duplicate another record (except itself)
   - Price validation same as "Create"
1. On save:
   - Updates existing `PriceHistory` record in-place
   - Persists changes to SwiftData
   - If edited record is the latest, `Asset.currentPrice` recalculates
   - If edited record was latest and no longer latest, recalculates to the new latest

**Delete Price Record**

**Validation:**

- Before allowing deletion, check if this is the last/only price record
- Constraint: `priceHistory.count >= 2` must be true to delete
- If constraint fails (last record):
  - Prevent deletion
  - Show info dialog: "An asset must have at least one price record"
  - Suggest alternatives: edit the record or delete the entire asset

**If validation passes (not the last record):**

1. User selects "Delete" on a price history entry
1. Confirmation dialog appears showing date of record
1. On confirmation:
   - Deletes `PriceHistory` record from SwiftData
   - If deleted record was the latest, `Asset.currentPrice` recalculates to remaining latest
   - All dependent calculations update accordingly

**Cascading delete (when asset is deleted):**

- All associated `PriceHistory` records deleted automatically via `.cascade` rule
- Asset deletion has no minimum price history requirement (entire asset is removed)

### Price Validation Rules

**Date Validation**

- Cannot be in the future
- Must be a valid date
- Must not duplicate an existing price record date for this asset
- Allows historical dates (including very old)
- No artificial limits on how far back prices can be recorded

**Price Validation**

- Must be a valid `Decimal` number
- Must be >= 0 (zero allowed for zero-value assets)
- No upper limit

**Deletion Constraint**

- An asset must maintain at least one price history record at all times
- Validation: `priceHistory.count >= 2` required before allowing deletion
- Prevents assets from becoming "priceless" and breaking value calculations
- Users can still delete the entire asset if needed (cascades all price history)

### Latest Price Display

**Asset List Screen**

- Show date of latest price next to current value
- Format: "Updated: Jan 15, 2025"
- If no price history: "No price recorded"
- Date is clickable to open price history modal (future enhancement)

**Asset Detail Screen**

- Display current price with recorded date
- Example: "$175.00 (Updated: Jan 15, 2025)"
- Include "View Price History" button to access modal

### Current Price Recalculation

Whenever price history changes, `Asset.currentPrice` recalculates:

1. If price history is not empty: Returns most recent (by date) price
1. If price history is empty: Returns 0
1. Duplicate dates are prevented, so this logic is deterministic

This ensures `currentValue` and all dependent calculations always reflect the latest available price.

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

## Financial Goal Progress

**Implementation Status**: ✅ Implemented

**Implementation Files**:

- **Service**: `AssetFlow/Services/SettingsService.swift` — stores financial goal
- **Calculator**: `AssetFlow/Services/GoalProgressCalculator.swift` — pure calculation functions
- **ViewModel**: `AssetFlow/ViewModels/SettingsViewModel.swift` — form state and validation
- **View**: `AssetFlow/Views/SettingsView.swift` — settings form UI
- **Display**: `AssetFlow/Views/OverviewView.swift` — goal progress card
- **Tests**: `AssetFlowTests/GoalProgressCalculationTests.swift`, `AssetFlowTests/SettingsServiceTests.swift`, `AssetFlowTests/SettingsViewModelTests.swift`

### Goal Achievement Rate

**Formula**:

```
Achievement Rate (%) = (Total Portfolio Value / Financial Goal) × 100
```

**Rules**:

- Returns 0% if goal is nil (no goal set)
- Returns 0% if goal is zero (prevents division by zero)
- Returns 0% if total value is zero
- Can exceed 100% when total value exceeds goal
- Uses total portfolio value converted to main currency

**Examples**:

| Total Value | Goal     | Achievement Rate |
| ----------- | -------- | ---------------- |
| $50,000     | $100,000 | 50%              |
| $100,000    | $100,000 | 100%             |
| $150,000    | $100,000 | 150%             |
| $50,000     | nil      | 0%               |
| $50,000     | $0       | 0%               |

### Distance to Goal

**Formula**:

```
Distance to Goal = Financial Goal - Total Portfolio Value
```

**Rules**:

- Returns 0 if goal is nil
- Positive value = below goal (amount needed to reach goal)
- Zero = exactly at goal
- Negative value = above goal (surplus amount)

**Examples**:

| Total Value | Goal     | Distance |
| ----------- | -------- | -------- |
| $40,000     | $100,000 | $60,000  |
| $100,000    | $100,000 | $0       |
| $120,000    | $100,000 | -$20,000 |

### Goal Reached Status

**Logic**: `totalValue >= goal`

- Returns `false` if goal is nil
- Returns `true` when total value equals or exceeds goal

### Goal Validation Rules

When setting a financial goal:

- Empty input is valid (clears the goal)
- Whitespace-only input treated as empty
- Must be a valid decimal number if provided
- Must be greater than zero if provided
- Validation messages:
  - "Financial goal must be a valid number."
  - "Financial goal must be greater than zero."

### Currency Integration

Goal progress calculations use the main currency setting:

1. Total portfolio value is calculated by converting all asset values to main currency
1. Financial goal is set in main currency
1. Distance to goal is displayed in main currency

When main currency changes, all displayed values update automatically.

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
