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
- **State Management**: How application state is maintained
- **Background Operations**: Async tasks, data sync, calculations

**What This Document Does NOT Cover**

- User interface design (see [UserInterfaceDesign.md](UserInterfaceDesign.md))
- Data model structure (see [DataModel.md](DataModel.md))
- System architecture (see [Architecture.md](Architecture.md))
- Testing strategies (see [TestingStrategy.md](TestingStrategy.md))

**Current Status**

🚧 **This document is a work in progress.** As business logic is implemented, this document will be updated to reflect actual rules, calculations, and workflows. Sections are organized by development phase to align with incremental implementation.

**How to Use This Document**

- **Developers**: Reference for implementing business rules and calculations
- **Product Managers**: Understand system behavior and constraints
- **QA Engineers**: Verify business logic through test cases
- **Future Contributors**: Understand decision rationale

**Related Documentation**

- [DataModel.md](DataModel.md) - Data structures and relationships
- [Architecture.md](Architecture.md) - MVVM layer responsibilities
- [UserInterfaceDesign.md](UserInterfaceDesign.md) - User-facing behavior

______________________________________________________________________

## Development Phases

### Phase 1: Core Asset Tracking (MVP)

**Scope**: Basic asset and transaction management

**Business Logic**

- Asset value calculations
- Transaction validation
- Cost basis tracking
- Simple gain/loss calculations

### Phase 2: Portfolio Management

**Scope**: Portfolio aggregation and allocation

**Business Logic**

- Portfolio total value computation
- Asset allocation by type
- Target vs actual allocation comparison
- Multi-portfolio aggregation

### Phase 3: Planning and Analysis

**Scope**: Investment planning and performance tracking

**Business Logic**

- Investment plan progress tracking
- Historical performance analysis
- Recommendation engine (basic)
- Goal achievement projections

### Phase 4: Advanced Features

**Scope**: Enhancements and optimizations

**Business Logic**

- Rebalancing suggestions
- Tax lot management
- Dividend reinvestment tracking
- Performance attribution

______________________________________________________________________

## Core Business Rules

### Universal Constraints

**Financial Precision**

- **Rule**: All monetary values MUST use `Decimal` type (never Float or Double)
- **Rationale**: Avoid floating-point precision errors in financial calculations
- **Enforcement**: Type system + code review
- **Extension**: Use `Decimal.formatted(currency:)` for display

**Currency Handling**

- **Rule**: Default currency is "USD"
- **Rule**: Currency must be specified for all monetary values
- **Future**: Multi-currency support with exchange rates (Phase 4+)

**Date Handling**

- **Rule**: All dates stored in UTC
- **Rule**: Display dates in user's local timezone
- **Rule**: Transaction dates cannot be in the future (validation)

**Data Integrity**

- **Rule**: Deleting a portfolio MUST handle associated assets (cascade or prevent)
- **Rule**: Deleting an asset MUST handle associated transactions (cascade or prevent)
- **Rule**: All required fields must be present before save (validation)

______________________________________________________________________

## Asset Management Logic

### Asset Value Calculation

**Current Value Computation** (Phase 1)

**For Quantity-Based Assets** (stocks, crypto, etc.)

```
Current Value = Quantity × Current Price per Unit
```

**For Fixed-Value Assets** (real estate, cash)

```
Current Value = User-entered value (manual update)
```

**Future Enhancement** (Phase 3+)

- Automatic price updates via API
- Historical value tracking
- Time-weighted returns

______________________________________________________________________

### Cost Basis Tracking

**Average Cost Method** (Phase 1)

**Formula**

```
Average Cost per Unit = Total Cost / Total Quantity
```

**Example**

- Buy 10 shares @ $100 = $1,000
- Buy 5 shares @ $110 = $550
- Average Cost = $1,550 / 15 = $103.33/share

**Implementation**

- Computed on-the-fly from transaction history
- Recalculated when new transactions added
- Supports partial sales (reduces quantity, preserves avg cost)

**Future Methods** (Phase 4+)

- FIFO (First In, First Out)
- LIFO (Last In, First Out)
- Specific lot identification
- Tax lot management

______________________________________________________________________

### Gain/Loss Calculation

**Unrealized Gain/Loss** (Phase 1)

**Formula**

```
Unrealized Gain = Current Value - Total Cost Basis
Unrealized Gain % = (Current Value - Cost Basis) / Cost Basis × 100
```

**Realized Gain/Loss** (Phase 2+)

**Formula**

```
Realized Gain = Sale Proceeds - Cost Basis of Sold Units
```

**Example**

- Buy 10 shares @ $100 = $1,000 cost basis
- Sell 5 shares @ $120 = $600 proceeds
- Cost basis of sold = $500 (5 shares × $100 avg)
- Realized Gain = $600 - $500 = $100

**Tax Considerations** (Phase 4+)

- Short-term vs long-term classification
- Tax reporting (Form 8949 data)

______________________________________________________________________

## Transaction Processing Logic

### Transaction Types

**Supported Types** (Phase 1)

1. **Buy**: Increases quantity and cost basis
1. **Sell**: Decreases quantity, realizes gain/loss
1. **Dividend**: Income, no quantity change
1. **Interest**: Income, no quantity change
1. **Fee**: Expense, reduces value

**Future Types** (Phase 3+)

- Split (stock splits, adjusts quantity)
- Transfer (between portfolios or accounts)
- Dividend Reinvestment (buy using dividend proceeds)

______________________________________________________________________

### Transaction Validation Rules

**Required Fields**

- Transaction type (must be valid enum value)
- Asset reference (must exist)
- Date (must be valid, not in future)
- Amount or quantity+price (depending on type)

**Type-Specific Validation**

**Buy Transaction**

- Quantity > 0
- Price per unit > 0
- Total amount = Quantity × Price (or manual override)

**Sell Transaction**

- Quantity > 0
- Quantity ≤ current holdings (cannot sell more than you own)
- Price per unit ≥ 0

**Dividend/Interest**

- Amount > 0
- No quantity required

**Fee**

- Amount > 0 (deducted from value)

**Business Rule Violation Handling**

- Display inline error message
- Disable save button until valid
- Suggest correction (e.g., "You only own 10 shares, cannot sell 15")

______________________________________________________________________

### Transaction Effects on Asset

**Buy Transaction Effect**

```
New Quantity = Old Quantity + Buy Quantity
New Total Cost = Old Total Cost + (Buy Quantity × Buy Price)
New Avg Cost = New Total Cost / New Quantity
```

**Sell Transaction Effect**

```
New Quantity = Old Quantity - Sell Quantity
New Total Cost = Old Total Cost - (Sell Quantity × Avg Cost)
Realized Gain = (Sell Price × Sell Quantity) - (Avg Cost × Sell Quantity)
```

**Dividend/Interest Effect**

```
Total Income += Dividend Amount
(No effect on quantity or cost basis)
```

**Fee Effect**

```
Total Fees += Fee Amount
(May reduce overall value in performance calculations)
```

______________________________________________________________________

## Portfolio Management Logic

### Portfolio Total Value

**Calculation** (Phase 2)

**Formula**

```
Portfolio Total Value = Σ (Asset Current Value) for all assets in portfolio
```

**Implementation**

- Computed property on Portfolio model
- Iterates through `assets` relationship
- Sums `currentValue` of each asset

**Example**

Portfolio "Tech":

- Asset A: $1,000
- Asset B: $2,500
- Asset C: $500
- Total: $4,000

______________________________________________________________________

### Asset Allocation Calculation

**By Asset Type** (Phase 2)

**Formula**

```
Allocation % = (Sum of asset values of type / Portfolio total value) × 100
```

**Example**

Portfolio Total: $10,000

- Stocks: $6,500 → 65%
- Bonds: $2,000 → 20%
- Crypto: $1,500 → 15%

**Implementation**

- Group assets by `assetType`
- Sum values per type
- Calculate percentage of total

**By Individual Asset** (Phase 2)

```
Asset Allocation % = (Asset Value / Portfolio Total Value) × 100
```

______________________________________________________________________

### Target Allocation vs Actual

**Target Allocation** (Phase 2)

**Data Structure**

```
Portfolio.targetAllocation: [String: Decimal]?
Example: ["Stock": 60, "Bond": 30, "Cash": 10]
```

**Comparison Logic**

For each asset type:

```
Actual % = (Actual value of type / Total value) × 100
Target % = targetAllocation[type] ?? 0
Difference = Actual % - Target %
```

**Display**

- Show side-by-side: Target vs Actual
- Highlight differences (color coding)
  - Green: Within tolerance (e.g., ±2%)
  - Yellow: Minor deviation (2-5%)
  - Red: Significant deviation (>5%)

______________________________________________________________________

### Rebalancing Suggestions (Phase 3)

**Algorithm** (Simple Version)

1. Calculate current allocation percentages
1. Compare to target allocation
1. For each over-allocated type:
   - Suggest selling: `(Actual % - Target %) × Total Value`
1. For each under-allocated type:
   - Suggest buying: `(Target % - Actual %) × Total Value`

**Example**

```
Portfolio: $10,000
Target: Stock 60%, Bond 40%
Actual: Stock 70%, Bond 30%
```

- Stocks over by 10% → Sell $1,000 of stocks
- Bonds under by 10% → Buy $1,000 of bonds

**Future Enhancement**

- Consider transaction costs
- Minimize number of trades
- Tax-aware rebalancing (avoid triggering capital gains)

______________________________________________________________________

### Multi-Portfolio Aggregation (Phase 2)

**Total Net Worth**

```
Total Net Worth = Σ (Portfolio Total Value) for all portfolios
```

**Overall Allocation**

```
Overall Allocation % = (Sum of all assets of type across portfolios / Total Net Worth) × 100
```

**Use Case**

- Dashboard shows aggregate view
- User can see total wealth distribution
- Even if assets are in different portfolios

______________________________________________________________________

## Investment Plan Logic (Phase 3)

### Plan Progress Tracking

**Data Model Fields**

- `targetAmount`: Goal amount (Decimal)
- `currentAmount`: Current progress (Decimal, optional)
- `targetDate`: Goal deadline (Date)
- `status`: Enum (active, completed, cancelled)

**Progress Calculation**

```
Progress % = (Current Amount / Target Amount) × 100
```

**Time Progress**

```
Days Elapsed = Today - Plan Start Date
Days Remaining = Target Date - Today
Time Progress % = (Days Elapsed / Total Days) × 100
```

**On Track Status**

```
If Progress % ≥ Time Progress %: On Track ✓
Else: Behind Schedule ⚠️
```

**Example**

- Target: $10,000 in 1 year
- Current: $4,000
- 6 months elapsed (50% of time)
- Progress: 40%
- Status: Behind (need 50%, have 40%)

______________________________________________________________________

### Monthly Contribution Suggestion

**Formula**

```
Required Monthly = (Target - Current) / Months Remaining
```

**Example**

- Target: $10,000
- Current: $4,000
- 6 months remaining
- Required: ($10,000 - $4,000) / 6 = $1,000/month

**Display**

"To reach your goal, save $1,000 per month."

______________________________________________________________________

### Risk Tolerance Mapping (Phase 3+)

**Risk Levels**

- Conservative: Low volatility, stable returns
- Moderate: Balanced risk/reward
- Aggressive: High growth potential, higher volatility

**Suggested Allocation** (Example Heuristics)

**Conservative**

- Bonds: 60%
- Stocks: 30%
- Cash: 10%

**Moderate**

- Stocks: 60%
- Bonds: 30%
- Cash: 10%

**Aggressive**

- Stocks: 80%
- Alternative (crypto, etc.): 15%
- Cash: 5%

**Recommendation Engine**

- Compare current allocation to suggested
- Highlight deviations
- Suggest adjustments to align with risk tolerance

______________________________________________________________________

## Performance Tracking (Phase 3)

### Time-Weighted Return (TWR)

**Purpose**: Measure investment performance, eliminating impact of deposits/withdrawals

**Formula** (Simplified)

```
TWR = (Ending Value - Starting Value - Net Contributions) / Starting Value × 100
```

**Example**

- Start: $10,000
- End: $12,000
- Net Contributions: $1,000 (deposited during period)
- TWR = ($12,000 - $10,000 - $1,000) / $10,000 = 10%

**Future Enhancement**

- True TWR with daily valuations
- Handle multiple cash flows accurately

______________________________________________________________________

### Money-Weighted Return (MWR)

**Purpose**: Measure actual return to investor, considering timing of contributions

**Formula** (Internal Rate of Return)

Complex calculation requiring iterative solving. Libraries may be used.

**Use Case**

- Investor wants to know personal return
- Accounts for when they added/withdrew money

______________________________________________________________________

### Historical Performance Chart (Phase 3)

**Data Requirements**

- Historical snapshots of portfolio value
- Store at regular intervals (daily, weekly, monthly)
- Alternative: Reconstruct from transaction history

**Chart Data**

- X-axis: Time (date range)
- Y-axis: Portfolio value
- Line chart showing value over time

**Comparison**

- Multiple portfolios on same chart
- Benchmark comparison (e.g., S&P 500 index)

______________________________________________________________________

## Data Validation Rules

### Asset Validation

**Required Fields**

- Name: Non-empty string
- Type: Must be valid asset type
- Current Value: Decimal ≥ 0

**Optional Fields**

- Symbol: String (for stocks, crypto)
- Description: String
- Portfolio: Reference (can be unassigned)

**Business Rules**

- Quantity ≥ 0 (cannot have negative shares)
- If quantity-based, quantity and price per unit must be consistent with current value

______________________________________________________________________

### Portfolio Validation

**Required Fields**

- Name: Non-empty string

**Optional Fields**

- Description: String
- Target Allocation: Dictionary of [AssetType: Percentage]

**Business Rules**

- Target allocation percentages should sum to 100% (warning if not)
- Cannot delete portfolio if assets are assigned (or cascade delete/reassign)

______________________________________________________________________

### Transaction Validation

**See "Transaction Validation Rules" section above**

Additional:

- Date cannot be more than 100 years in past (sanity check)
- Amount/quantity decimal precision: 2-8 decimal places depending on asset type

______________________________________________________________________

## State Management

### Application State

**SwiftData Auto-Persistence**

- No manual save calls needed
- Changes to models auto-persist
- `@Query` provides reactive updates

**User Preferences** (Phase 2+)

- Default currency
- Preferred chart types
- Date range defaults
- Stored in UserDefaults or app settings

**Session State**

- Selected portfolio/asset (navigation)
- Filter/sort preferences (in-memory)
- Search query state

______________________________________________________________________

### Computed vs Stored Values

**Computed (Calculated on Demand)**

- Portfolio total value
- Asset allocation percentages
- Unrealized gain/loss
- Average cost basis

**Stored (Persisted in Database)**

- Asset current value (until auto-fetch implemented)
- Transaction amounts
- Quantities
- User-entered data

**Rationale**

- Computed: Always up-to-date, no sync issues
- Stored: Source of truth, user-controlled data

______________________________________________________________________

## Background Operations (Future)

### Automatic Price Updates (Phase 3+)

**Strategy**

- Fetch current prices from API (e.g., Yahoo Finance, CoinGecko)
- Update asset `currentValue` automatically
- Run on app launch and/or periodic background task

**Throttling**

- Cache prices for 15-60 minutes
- Avoid excessive API calls
- Respect rate limits

**Error Handling**

- If fetch fails, use last known value
- Display staleness indicator (e.g., "Price as of 2 hours ago")

______________________________________________________________________

### Data Sync (Phase 4+)

**iCloud Sync**

- Use CloudKit or SwiftData iCloud sync
- Keep data synced across user's devices
- Conflict resolution strategy

**Export/Import**

- Export to CSV for backup
- Import from other platforms (e.g., mint, personal capital)

______________________________________________________________________

## Calculation Examples

### Example 1: Buy and Hold Stock

**Scenario**

- Buy 10 shares of AAPL @ $150 on Jan 1
- Current price: $165 on Feb 1

**Calculations**

- Total Cost: 10 × $150 = $1,500
- Current Value: 10 × $165 = $1,650
- Unrealized Gain: $1,650 - $1,500 = $150
- Gain %: $150 / $1,500 = 10%

______________________________________________________________________

### Example 2: Multiple Buys, Average Cost

**Scenario**

- Buy 10 shares @ $150 = $1,500
- Buy 5 shares @ $160 = $800
- Total: 15 shares, Total Cost: $2,300

**Average Cost**

- Avg: $2,300 / 15 = $153.33/share

**Current Value** (price now $165)

- Value: 15 × $165 = $2,475
- Gain: $2,475 - $2,300 = $175 (7.6%)

______________________________________________________________________

### Example 3: Sell Partial Position

**Scenario**

- Own 15 shares, avg cost $153.33
- Sell 5 shares @ $170

**Realized Gain**

- Proceeds: 5 × $170 = $850
- Cost Basis: 5 × $153.33 = $766.65
- Realized Gain: $850 - $766.65 = $83.35

**Remaining Position**

- Quantity: 10 shares
- Cost Basis: 10 × $153.33 = $1,533.30
- (Average cost per share unchanged)

______________________________________________________________________

### Example 4: Portfolio Allocation

**Portfolio Total: $10,000**

**Assets**

- AAPL (Stock): $3,000
- MSFT (Stock): $2,000
- BTC (Crypto): $1,500
- Treasury Bond (Bond): $2,000
- Cash: $1,500

**Allocation by Type**

- Stocks: ($3,000 + $2,000) = $5,000 → 50%
- Crypto: $1,500 → 15%
- Bonds: $2,000 → 20%
- Cash: $1,500 → 15%

**Comparison to Target** (60% stock, 20% bond, 20% cash)

- Stocks: 50% (target 60%) → Under by 10%
- Bonds: 20% (target 20%) → On target ✓
- Cash: 15% (target 20%) → Under by 5%
- Crypto: 15% (target 0%) → Over by 15%

**Rebalancing Suggestion**

- Sell $1,500 crypto
- Buy $1,000 stocks, $500 cash

______________________________________________________________________

## Edge Cases and Error Handling

### Edge Case: Zero Quantity After Sale

**Scenario**: Sell all shares of an asset

**Behavior**

- Asset quantity → 0
- Cost basis → $0
- Asset remains in system (historical record)
- Option to delete asset if desired

______________________________________________________________________

### Edge Case: Negative Values

**Scenario**: Fees exceed asset value

**Behavior**

- Asset value can go to $0
- Cannot go negative (validation prevents)
- Warning displayed if fee would cause negative

______________________________________________________________________

### Edge Case: Transaction Date Before Asset Created

**Scenario**: User tries to record transaction dated before asset existed

**Validation**

- Allow (asset purchase date is earliest transaction date)
- Or enforce: Transaction date ≥ asset creation date

**Decision**: Allow, derive asset creation from earliest transaction

______________________________________________________________________

### Edge Case: Portfolio with No Assets

**Behavior**

- Total value: $0
- Allocation chart: Empty state
- Message: "Add assets to this portfolio"

______________________________________________________________________

### Edge Case: Division by Zero

**Scenario**: Calculate percentage when total value is $0

**Handling**

- Check denominator before division
- Return 0% or N/A
- Display appropriate message

______________________________________________________________________

## Business Logic Testing

### Key Test Scenarios

**Asset Value Calculation**

- Test with single buy
- Test with multiple buys (average cost)
- Test with buy and sell
- Test with zero quantity

**Transaction Validation**

- Test all required fields
- Test sell > holdings (should fail)
- Test negative amounts (should fail)
- Test future dates (should fail)

**Portfolio Aggregation**

- Test single asset portfolio
- Test multi-asset portfolio
- Test portfolio with no assets

**Allocation Calculation**

- Test with various asset types
- Test with zero total value
- Test rounding (percentages sum to 100%)

**Edge Cases**

- All edge cases listed above
- Boundary values (very large amounts, very small decimals)

______________________________________________________________________

## Future Enhancements

### Phase 4+

**Tax Optimization**

- Tax lot selection (minimize capital gains)
- Harvest tax losses
- Track short-term vs long-term holdings

**Advanced Analytics**

- Sharpe ratio, alpha, beta
- Sector allocation
- Geographic allocation
- Correlation analysis

**Automation**

- Automatic rebalancing
- Recurring contributions
- Dividend reinvestment plans

**Multi-Currency**

- Support multiple currencies
- Exchange rate handling
- Currency conversion in reports

______________________________________________________________________

## References

### Financial Concepts

- [Investopedia - Cost Basis](https://www.investopedia.com/terms/c/costbasis.asp)
- [Investopedia - Time-Weighted Return](https://www.investopedia.com/terms/t/time-weightedror.asp)
- [Investopedia - Asset Allocation](https://www.investopedia.com/terms/a/assetallocation.asp)

### Calculation Libraries

- Swift `Decimal` type for precision
- Swift Charts for visualization
- Potential future: Financial calculation libraries

______________________________________________________________________

**Document Status**: 🚧 Initial framework - update as business logic is implemented

**Last Updated**: 2025-10-09

**Next Action**: Implement Phase 1 logic (asset value, transaction validation, basic gain/loss)
