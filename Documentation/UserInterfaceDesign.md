# User Interface Design

## Preface

**Purpose of this Document**

This document describes the user interface design for AssetFlow - **what** users see and **how** they interact with the application across macOS, iOS, and iPadOS platforms. This document is separated into two main parts:

1. **Design Specification** - Visual design, user experience, and interaction patterns
1. **Implementation Guide** - Technical notes for building the designs in SwiftUI

This separation allows design thinking to happen independently from implementation details, while still providing practical guidance for a single-developer project.

**What This Document Will Cover**

**Part 1: Design Specification**

- Development phases and priorities
- Screen designs and layouts
- Navigation and user flows
- Visual style and components
- Platform-specific adaptations

**Part 2: Implementation Guide**

- SwiftUI patterns and code approaches
- Component implementation notes
- Platform-specific code patterns
- Accessibility implementation
- Development checklist

**Design Philosophy for Single-Developer Projects**

- **Iterate in code**: Use Xcode previews instead of separate mockup tools
- **Leverage platform defaults**: Start with native SwiftUI components
- **Prioritize functionality**: Working features before visual polish
- **Evolve organically**: Refine based on actual usage, not speculation

______________________________________________________________________

# Part 1: Design Specification

## Development Priority and Phases

### Phase 1: MVP Foundation (Current)

**Goal**: Core asset tracking functionality

**Screens**

1. Asset List - View and search all assets
1. Asset Detail - View/edit individual assets
1. Transaction Entry - Record buy/sell transactions

**Design Focus**: Clean, functional layouts using standard patterns

### Phase 2: Portfolio Organization

**Goal**: Group assets and view allocations

**Screens**

1. Portfolio List - View all portfolios
1. Portfolio Detail - Asset allocation and holdings
1. Dashboard - Portfolio summary overview

**Design Focus**: Data visualization (basic charts), information hierarchy

### Phase 3: Planning and Analysis

**Goal**: Investment planning and performance tracking

**Screens**

1. Investment Plan Management
1. Performance Charts and Analytics

**Design Focus**: Advanced visualizations, comparative views

### Phase 4: Live Data Integration

**Goal**: Automate asset pricing with live data.

**Screens**

1. Settings screen for API key management.
1. UI indicators for live vs. stale prices.

**Design Focus**: Clear communication of data freshness, non-blocking UI during updates, error states for API failures.

### Phase 5: Polish & Advanced Integrations

**Goal**: Refined user experience and add powerful automation features.

**Focus**: Dark mode optimization, accessibility, error states, platform-specific enhancements, rebalancing suggestions, iCloud sync, data import/export.

______________________________________________________________________

## Screen Designs

### Overview Screen (macOS Default Landing Page)

**Primary Purpose**: High-level dashboard showing total portfolio value and portfolio summary

**Visual Layout**

```
┌──────────────────────────────────────────────────┐
│  Overview                                        │
├──────────────────────────────────────────────────┤
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  Total Portfolio Value                     │  │
│  │  $45,230.00                                │  │
│  │  📊 3 Portfolios                           │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  Portfolios                                      │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  Tech Stocks              $15,750.00       │  │
│  │  5 assets                                  │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  Real Estate              $25,000.00       │  │
│  │  2 assets                                  │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  Crypto                   $4,480.00        │  │
│  │  3 assets                                  │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Information Sections**

1. **Total Value Card**: Aggregated value across all portfolios with portfolio count
1. **Portfolio Summary List**: Each portfolio shown with name, asset count, and total value

**Interactions**

- Click "Add Portfolio" button in toolbar → Opens portfolio creation form
- Use sidebar to navigate to specific portfolios or "All Portfolios" view

**Loading State**:

While fetching exchange rates for multi-currency conversion:

- Total Value Card shows: Spinning progress indicator + "Loading rates..." text
- Portfolio Summary rows show: Spinning progress indicator in place of values
- Prevents display of incorrect unconverted values

**Current Implementation (Phase 1 MVP)**:

- ✅ Total portfolio value calculation with currency conversion
- ✅ Portfolio count display
- ✅ Portfolio summary cards with name, asset count, and value
- ✅ Add Portfolio button in toolbar
- ✅ Loading state while fetching exchange rates (no incorrect values displayed)
- 🚧 Performance metrics (Phase 2)
- 🚧 Recent activity feed (Phase 2)
- 🚧 Allocation charts (Phase 2)

______________________________________________________________________

### Asset List Screen

**Primary Purpose**: Browse and manage all assets

**Visual Layout**

```
┌──────────────────────────────────────────────────┐
│  Assets                            [+ Add Asset] │
├──────────────────────────────────────────────────┤
│  🔍 Search assets...                             │
├──────────────────────────────────────────────────┤
│                                                  │
│  📈  Apple Inc. (AAPL)                           │
│      Stock • Portfolio: Tech                     │
│      $1,250.00               +5.2% ↗             │
│                                                  │
│  🪙  Bitcoin                                     │
│      Cryptocurrency • Portfolio: Crypto          │
│      $4,500.00               -2.1% ↘             │
│                                                  │
│  🏠  Rental Property                             │
│      Real Estate • Unassigned                    │
│      $250,000.00             +0.3% ↗             │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Information Hierarchy**

1. Asset name (bold, prominent)
1. Asset type and portfolio assignment (secondary text)
1. Current value (large, monetary formatting)
1. Performance (percentage with color coding and trend arrow)

**Interactions**

- Tap/click row → Navigate to Asset Detail
- Tap "Add Asset" → Show Asset Entry form
- Search field → Filter list in real-time
- Right-click/context menu (macOS) → Edit or Delete asset
- Swipe row (iOS) → Quick actions (Edit, Delete)

**Context Menu Options**:

- **Edit**: Opens asset form in edit mode
- **Delete**: Shows confirmation dialog before deletion

**Empty State**

- Icon: 📊 chart icon
- Message: "No assets yet"
- Action: "Add your first asset" button

______________________________________________________________________

### Asset Detail Screen

**Implementation Status**: ✅ Implemented in `AssetFlow/Views/AssetDetailView.swift`

**Primary Purpose**: View and edit complete asset information

**Visual Layout**

```
┌──────────────────────────────────────────────────┐
│  ← Assets                              [Edit]    │
├──────────────────────────────────────────────────┤
│                                                  │
│  📈 Apple Inc. (AAPL)                            │
│  Stock                                           │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  Current Value                             │  │
│  │  $1,250.00                                 │  │
│  │                                            │  │
│  │  Quantity: 10 shares                       │  │
│  │  Avg. Cost: $110.00/share                  │  │
│  │  Total Cost: $1,100.00                     │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  Performance                               │  │
│  │                                            │  │
│  │  Unrealized Gain                           │  │
│  │  +$150.00   (+13.6%) ↗                     │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  Recent Transactions                             │
│                                                  │
│  Buy     10 shares @ $110.00    Jan 15, 2025     │
│                                                  │
│  [View All Transactions]                         │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Information Sections**

1. **Header**: Asset name, type, icon
1. **Value Card**: Current value, quantity, cost basis
1. **Performance Card**: Gain/loss with visual indicators
1. **Transaction Summary**: Recent transactions with link to full history

**Interactions**

- Tap "Edit" → Enter edit mode or navigate to edit screen
- Tap "View Price History" → Opens price history modal
- Tap "View Transaction History" → Opens transaction history modal
- Tap "Record Transaction" → Opens record transaction form
- Tap transaction row → View transaction detail
- Tap "View All Transactions" → Navigate to filtered transaction list

______________________________________________________________________

### Transaction Entry Screen

**Primary Purpose**: Record financial transactions

**Visual Layout**

```
┌──────────────────────────────────────────────────┐
│  ✕ Cancel                  Add Transaction  Save │
├──────────────────────────────────────────────────┤
│                                                  │
│  Transaction Type *                              │
│  [ Buy ▼ ]                                       │
│                                                  │
│  Asset *                                         │
│  [ Apple Inc. (AAPL) ▼ ]                         │
│                                                  │
│  Date *                                          │
│  [ Jan 15, 2025 📅 ]                             │
│                                                  │
│  Quantity *                                      │
│  [ 10 ]                                          │
│                                                  │
│  Price per Unit *                                │
│  [ $110.00 ]                                     │
│                                                  │
│  Total Amount                                    │
│  $1,100.00 (calculated)                          │
│                                                  │
│  Notes (optional)                                │
│  [ _________________________________ ]           │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Form Fields**

- Transaction Type: Picker (Buy, Sell, Dividend, Interest, Fee, etc.)
- Asset: Picker or pre-filled if opened from asset detail
- Date: Date picker (defaults to today)
- Quantity: Decimal number input
- Price per Unit: Currency input
- Total Amount: Auto-calculated or manual override
- Notes: Optional text field

**Validation**

- Required fields marked with \*
- "Save" button disabled until all required fields valid
- Inline error messages for invalid inputs (e.g., "Must be a positive number")

**Interactions**

- Tap "Cancel" → Discard and dismiss
- Tap "Save" → Validate, save, dismiss, return to previous screen
- Change quantity/price → Auto-update total

______________________________________________________________________

### Portfolio List Screen

**Primary Purpose**: Browse and manage all portfolios

**Visual Layout**

```
┌──────────────────────────────────────────────────┐
│  Portfolios                        [+ Add]       │
├──────────────────────────────────────────────────┤
│                                                  │
│  Tech Stocks                                     │
│  High-growth technology portfolio                │
│                                                  │
│  Real Estate                                     │
│  Residential properties                          │
│                                                  │
│  Retirement                                      │
│  Long-term retirement savings                    │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Interactions**

- Tap/click portfolio row → Navigate to Portfolio Detail screen (future: shows assets, allocation, performance)
- Tap "Add" button → Show portfolio creation form in popup/sheet
- Right-click portfolio (macOS) → Context menu with "Edit Portfolio" and "Delete Portfolio" options

**Context Menu Actions** (macOS):

**Edit Portfolio:**

1. Right-click on portfolio row
1. Context menu appears with "Edit Portfolio" option (pencil icon)
1. User selects "Edit Portfolio"
1. Edit form appears in a popup/sheet
1. User can modify portfolio name and description
1. Save or Cancel to dismiss

**Delete Portfolio:**

1. Right-click on portfolio row
1. Context menu appears with "Delete Portfolio" option (trash icon, destructive style)
1. User selects "Delete Portfolio"
1. System validates portfolio is empty
1. **If valid (empty portfolio)**:
   - Confirmation alert appears
   - Title: "Delete Portfolio?"
   - Message: "Are you sure you want to delete '[Portfolio Name]'? This action cannot be undone."
   - Buttons: "Cancel" (default) and "Delete" (destructive)
   - User clicks "Delete" → Portfolio removed from system
1. **If invalid (has assets)**:
   - Error alert appears
   - Title: "Cannot Delete Portfolio"
   - Message: "Cannot delete portfolio"
   - Recovery: "This portfolio contains N asset(s). Remove all assets before deleting the portfolio."
   - Button: "OK"
   - Portfolio remains intact

**Delete Validation**:

- Empty portfolios: Show confirmation dialog
- Non-empty portfolios: Show error with asset count
- Error message includes recovery suggestion (remove assets first)
- Re-validation occurs before final deletion (edge case: state changes during confirmation)

**Empty State**

- Icon: Folder with plus badge (large, centered)
- Message: "No portfolios yet"
- Subtext: "Add your first portfolio to get started"
- Action: "Add Portfolio" button (prominent style)

______________________________________________________________________

### Portfolio Detail Screen

**Primary Purpose**: View portfolio composition, allocation, and manage assets

**Note**: The Portfolio List shows portfolio names and descriptions with an edit popup. The Portfolio Detail screen (accessed via navigation) displays the full portfolio content including assets, allocation charts, and portfolio performance.

**Visual Layout**

```
┌──────────────────────────────────────────────────┐
│  ← Portfolios                          [Edit]    │
├──────────────────────────────────────────────────┤
│                                                  │
│  Tech Portfolio                                  │
│                                                  │
│  Total Value: $15,750.00                         │
│  Return: +$1,250.00 (+8.6%)                      │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │    Asset Allocation                        │  │
│  │                                            │  │
│  │         ╱───────╲                          │  │
│  │        │  Chart  │                         │  │
│  │         ╲───────╱                          │  │
│  │                                            │  │
│  │  ■ Stocks 65%      ■ Crypto 25%            │  │
│  │  ■ Bonds 10%                               │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  Holdings                                        │
│                                                  │
│  📈 Apple Inc.         $1,250.00    8%   +5.2%   │
│  📈 Microsoft Corp.    $2,100.00   13%   +3.1%   │
│  🪙 Bitcoin           $4,500.00   29%   -2.1%    │
│  ...                                             │
│                                                  │
│  [Add Asset to Portfolio]                        │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Information Sections**

1. **Header**: Portfolio name, total value, overall return
1. **Allocation Chart**: Visual breakdown by asset type (pie/donut chart)
1. **Holdings List**: Individual assets with value, allocation %, performance

**Interactions**

- Tap "Edit" → Edit portfolio details via context menu (name, description)
- Tap asset row → Navigate to asset detail (future implementation)
- Right-click/context menu on asset → Edit or Delete asset
- Tap "Add Asset" → Add existing asset or create new one (future implementation)

**Asset Row Context Menu**:

- **Edit**: Opens asset form for editing
- **Delete**: Shows confirmation dialog before deletion

**Asset List Display Details**:

- For **cash assets**: Shows only total value (quantity hidden - not meaningful for cash)
- For **other assets**: Shows quantity + total value
- Loading state while fetching exchange rates (same as Overview)

**Current Implementation (Phase 1 MVP)**:

- ✅ Displays portfolio name and description
- ✅ Shows total portfolio value with currency conversion
- ✅ Lists all assets with their name, type, quantity (hidden for cash), and current value
- ✅ Empty state when portfolio has no assets
- ✅ Navigation: Click portfolio from Portfolio List → View Portfolio Detail
- ✅ Add Asset functionality (sheet-based form)
- ✅ Edit Asset functionality (context menu on asset rows)
- ✅ Delete Asset functionality (context menu with confirmation dialog)
- ✅ Asset form validation (name, quantity, current value)
- ✅ Loading state while fetching exchange rates
- ✅ Cascading delete of transactions and price history
- ✅ Asset rows navigate to Asset Detail screen (NavigationLink)
- ✅ "View Price History" context menu on asset rows
- ✅ Price history sheet accessible from context menu
- ✅ Latest price date shown in asset rows
- 🚧 Asset allocation chart (Phase 2)
- 🚧 Performance metrics (Phase 2)

**Chart Colors** (Phase 2+)

- Use distinct, accessible colors for asset types
- Include legend with percentages

______________________________________________________________________

### Price History Modal

**Implementation Status**: ✅ Implemented in `AssetFlow/Views/PriceHistoryView.swift`

**Primary Purpose**: View, add, edit, and delete historical price records for an asset

**Access Points**

- **macOS**:

  - Context menu on asset row (Asset List) → "View Price History"
  - Button/link in Asset Detail screen
  - Right-click on "Latest Price Date" field (future enhancement)

- **iOS/iPadOS**:

  - Long-press on asset row → "View Price History"
  - Swipe action on asset row
  - Button in Asset Detail screen

**Visual Layout (macOS Modal)**

```
┌──────────────────────────────────────────────────┐
│  ✕ Price History - Apple Inc. (AAPL)             │
├──────────────────────────────────────────────────┤
│                                                  │
│  Asset: Apple Inc. (AAPL) | Stock | USD          │
│  Current Price: $175.00 (Updated: Jan 15, 2025)  │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │ Price History                              │  │
│  ├────────────────────────────────────────────┤  │
│  │ Date         │  Price      │  Actions      │  │
│  ├────────────────────────────────────────────┤  │
│  │ Jan 15, 2025 │  $175.00    │ Edit | Delete │  │
│  │ Jan 10, 2025 │  $170.50    │ Edit | Delete │  │
│  │ Jan 5, 2025  │  $168.00    │ Edit | Delete │  │
│  │ Dec 30, 2024 │  $165.00    │ Edit | Delete │  │
│  │ Dec 25, 2024 │  $162.50    │ Edit | Delete │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  [+ Add Price Record]                            │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Information Display**

1. **Header**: Asset name, type, and currency
1. **Current Price Summary**: Shows latest price and date
1. **Price History List**: Table or list showing:
   - Date (sorted newest first)
   - Price (formatted as currency)
   - Quick action buttons: Edit, Delete
1. **Add Button**: Prominent button to create new price record

**Interactions**

- **Edit**: Click "Edit" button → Opens edit form (sheet or inline)
- **Delete**: Click "Delete" button → Shows confirmation dialog
- **Add**: Click "+ Add Price Record" → Opens form to add new record
- **Close**: Click X or press Escape → Dismiss modal

**Empty State**

- Message: "No price history yet"
- Shows add button to create first price record

______________________________________________________________________

### Transaction History Modal

**Implementation Status**: ✅ Implemented in `AssetFlow/Views/TransactionHistoryView.swift`

**Primary Purpose**: View a chronological list of transactions for an asset

**Access Points**

- **macOS/iOS**:

  - Button in Asset Detail screen → "View Transaction History"

**Visual Layout (macOS Modal)**

```
┌──────────────────────────────────────────────────┐
│  ✕ Transaction History - Apple Inc.         [+]  │
├──────────────────────────────────────────────────┤
│                                                  │
│  Asset: Apple Inc. | Stock | USD                 │
│  Current Price: $175.00 | 3 transaction(s)       │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │ Type    │ Date       │ Quantity │ Total     │  │
│  ├────────────────────────────────────────────┤  │
│  │ Buy     │ Jan 15     │ 10      │ $1,750.00 │  │
│  │ Sell    │ Jan 10     │ 5       │ $850.00   │  │
│  │ Buy     │ Jan 5      │ 20      │ $3,360.00 │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Information Display**

1. **Header**: Asset name, type, currency, current price, transaction count
1. **Transaction Table (macOS)**: Table with 4 columns — Type, Date, Quantity, Total Amount
1. **Transaction List (iOS)**: Two-row layout per transaction (type+date top, quantity+amount bottom)
1. **Cash-friendly labels**: For cash assets, "Buy" displays as "Deposit" and "Sell" as "Withdrawal"

**Interactions**

- **Add**: Click "+" button → Opens "Record Transaction" form
- **Close**: Click "Close" or press Escape → Dismiss modal

**Empty State**

- Icon: `list.bullet.rectangle` (large, centered)
- Message: "No transactions yet"
- Subtext: "Record your first transaction for this asset"
- Action: "Record Transaction" button (prominent style)

**Platform Behavior**

- **macOS**: Uses `Table` component with 4 columns, minimum frame 600×400
- **iOS**: Uses `List` with two-row layout per transaction

______________________________________________________________________

### Record Transaction Form

**Implementation Status**: ✅ Implemented in `AssetFlow/Views/TransactionFormView.swift`

**Primary Purpose**: Record a new financial transaction for an asset

**Visual Layout**

```
┌──────────────────────────────────────────────────┐
│  ✕ Cancel             Record Transaction    Save │
├──────────────────────────────────────────────────┤
│                                                  │
│  ↔ Transaction Details                           │
│  ┌────────────────────────────────────────────┐  │
│  │ Type: [ Buy ▼ ]                            │  │
│  │                                            │  │
│  │ Date: [ Jan 15, 2025 📅 ]                  │  │
│  │                                            │  │
│  │ Quantity: [ 10 ]                           │  │
│  │                                            │  │
│  │ Price per Unit (USD): [ $175.00 ]          │  │
│  │                                            │  │
│  │ Total Amount: $1,750.00                    │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Form Fields**

1. **Transaction Type** (Required): Picker with all transaction types
   - For cash assets: "Buy" shows as "Deposit", "Sell" shows as "Withdrawal"
1. **Date** (Required): Date picker, defaults to today
   - Cannot be in the future
1. **Quantity / Amount** (Required): Decimal number input
   - Labeled "Amount" for cash assets, "Quantity" for others
   - Must be greater than zero
   - For sell/transferOut: Cannot exceed current holdings
1. **Price per Unit** (Required, non-cash only): Currency input, pre-filled with asset's current price
   - Hidden for cash assets (price is always 1)
   - Must be zero or greater (allows free transfers)
1. **Total Amount** (Read-only, non-cash only): Auto-calculated as quantity × price per unit
   - Hidden for cash assets (total always equals the amount)
   - Shows "—" if inputs are invalid

**Validation**

- Save button disabled until all fields valid
- Real-time validation messages shown in red below fields
- Sell/transferOut quantity capped at current holdings
- Messages shown only after user interaction (interaction flags)

**Interactions**

- **Cancel**: Dismiss without saving
- **Save**: Validate and create transaction, dismiss
- **Type change**: Re-validates quantity for sell/transferOut constraints

______________________________________________________________________

### Add/Edit Price Record Form

**Implementation Status**: ✅ Implemented in `AssetFlow/Views/PriceHistoryFormView.swift`

**Primary Purpose**: Create or modify a price history record

**Visual Layout**

```
┌──────────────────────────────────────────────────┐
│  ✕ Cancel               Add Price Record    Save │
├──────────────────────────────────────────────────┤
│                                                  │
│  Date *                                          │
│  [ Jan 15, 2025 📅 ]                             │
│  Cannot be in the future                         │
│                                                  │
│  Price *                                         │
│  [ $175.00 ]                                     │
│  Must be a positive number                       │
│                                                  │
│  [Cancel]                           [Save]       │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Form Fields**

1. **Date** (Required): Date picker

   - Default: Today's date
   - Cannot be in the future
   - Validates on blur and submit

1. **Price** (Required): Currency input field

   - Default: Empty (for new) or existing price (for edit)
   - Must be >= 0
   - Accepts decimal values
   - Formatted as currency with locale-aware separator

**Validation**

- Save button disabled until all required fields are valid
- Real-time validation messages:
  - Date: "Date cannot be in the future"
  - Price: "Price must be a positive number"
  - Empty fields: "[Field name] is required"
- Messages shown in red below their respective fields

**Interactions**

- **Cancel**: Dismiss without saving
- **Save**: Validate and persist to SwiftData
  - If new: Create PriceHistory record, asset.currentPrice updates
  - If edit: Update existing record, asset.currentPrice recalculates
- **Date picker**: Click to open date selector
- **Price field**: Type to enter or edit price

**Editing Mode (Prepopulated)**

When editing an existing record:

- Date field shows the current date
- Price field shows the current price
- Form title: "Edit Price Record"
- Submit button: "Save Changes"

**Delete Confirmation Dialog**

**When deleting a non-final record:**

```
┌──────────────────────────────────────────────────┐
│  Delete Price Record?                            │
├──────────────────────────────────────────────────┤
│                                                  │
│  Are you sure you want to delete the price       │
│  record from Jan 15, 2025?                       │
│                                                  │
│  [Cancel]                      [Delete] ⚠️       │
│                                                  │
└──────────────────────────────────────────────────┘
```

**When trying to delete the last/only record:**

```
┌──────────────────────────────────────────────────┐
│  Cannot Delete Last Price Record                 │
├──────────────────────────────────────────────────┤
│                                                  │
│  An asset must have at least one price record.   │
│                                                  │
│  You can:                                        │
│  • Edit this record to update the price          │
│  • Delete the entire asset if no longer needed   │
│                                                  │
│  [OK]                                            │
│                                                  │
└──────────────────────────────────────────────────┘
```

**UI Behavior:**

- Delete button is disabled (grayed out) on the last price record
- Hover/tooltip on disabled button explains why: "Cannot delete the last price record"
- This prevents accidental deletion and maintains data integrity

______________________________________________________________________

### Asset Form (Add/Edit Asset)

**Primary Purpose**: Create new assets or edit existing asset properties

**Visual Layout**

```
┌──────────────────────────────────────────────────┐
│  ← Cancel                  New Asset      Save   │
├──────────────────────────────────────────────────┤
│                                                  │
│  Asset Details                                   │
│  ┌────────────────────────────────────────────┐  │
│  │ Name: [Apple Inc.              ]           │  │
│  │ Asset Type: [Stock            ▼]           │  │
│  │ Currency: [USD                 ]           │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  Initial Position (new assets only)              │
│  ┌────────────────────────────────────────────┐  │
│  │ Quantity: [10                  ]           │  │
│  │ Current Price: [150.50         ]           │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  Notes                                           │
│  ┌────────────────────────────────────────────┐  │
│  │ Notes (optional):                          │  │
│  │ [                              ]           │  │
│  │ [                              ]           │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Form Fields**

1. **Name** (Required): Asset name (e.g., "Apple Inc.", "Bitcoin")

   - Validation: Cannot be empty
   - Trimmed whitespace

1. **Asset Type** (Required): Picker with predefined types

   - Stock, Bond, Cryptocurrency, Real Estate, Commodity, Cash, Mutual Fund, ETF, Other
   - Default: Stock

1. **Currency** (Required): Currency code

   - Default: "USD"
   - Plain text field for flexibility

1. **Quantity** (Required for new assets): Initial quantity held

   - For **cash assets**: Labeled as "Amount" (e.g., $5,000)
   - For **other assets**: Standard quantity field
   - Validation: Must be a positive number greater than zero
   - Accepts decimal values
   - For editing: Read-only (managed via transactions)

1. **Current Price** (Required for new assets): Initial price per unit

   - For **cash assets**: Automatically set to 1 (no user input needed)
   - For **other assets**: User enters price per unit
   - Validation: Must be a number >= 0
   - Accepts decimal values
   - For editing: Read-only (managed via price history)

1. **Notes** (Optional): Free-form text notes

**Validation Behavior**

- Save button disabled when validation errors exist
- Real-time validation on name field
- Validation messages shown in red below fields
- Empty state shows validation message after user interaction

**Interactions**

- Tap "Cancel" → Dismiss form without saving
- Tap "Save" → Validate and save asset, dismiss form
- Save button disabled when form invalid

**Current Implementation**:

- ✅ Form validation for all required fields
- ✅ Sheet presentation on macOS/iOS
- ✅ Real-time validation feedback
- ✅ Separate behavior for new vs. editing assets
- ✅ Automatic creation of initial transaction and price history for new assets
- ✅ Context menu integration for editing existing assets
- ✅ Special UX for cash assets (single "Amount" field, automatic price=1)
- ✅ Context-aware validation messages ("Amount" vs "Quantity")

______________________________________________________________________

### Dashboard Screen (Phase 2)

**Primary Purpose**: Overview of all portfolios and total wealth

**Visual Layout**

```
┌──────────────────────────────────────────────────┐
│  Dashboard                                       │
├──────────────────────────────────────────────────┤
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  Total Portfolio Value                     │  │
│  │  $45,230.00                                │  │
│  │  +$3,120.00 (+7.4%) this month             │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  ┌────────────────────────────────────────────┐  │
│  │  Overall Allocation                        │  │
│  │  [Pie Chart across all portfolios]         │  │
│  └────────────────────────────────────────────┘  │
│                                                  │
│  Portfolios                                      │
│                                                  │
│  Tech Portfolio        $15,750  +8.6%   ───────  │
│  Retirement            $25,000  +6.2%   ───────  │
│  Crypto                $4,480   -2.5%   ───────  │
│                                                  │
│  Recent Activity                                 │
│                                                  │
│  Buy AAPL    +10 shares              Jan 15      │
│  Dividend    +$25.50                 Jan 12      │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Purpose**: Quick glance at financial status, entry point to deeper views

______________________________________________________________________

### Investment Plan Management Screen (Phase 3)

**Primary Purpose**: Create, view, and manage all investment plans, including goal-based plans and regular saving schedules.

**Visual Layout (List View)**

```
┌──────────────────────────────────────────────────┐
│  Investment Plans                  [+ New Plan]  │
├──────────────────────────────────────────────────┤
│                                                  │
│  ⭐ Retirement 2050 (Goal)                       │
│     Target: $1,000,000 by 2050-01-01             │
│     On track                                     │
│                                                  │
│  💰 Monthly S&P 500 Plan (Recurring)             │
│     $100.00 weekly into VOO from Cash            │
│     Next run: Oct 17, 2025 (Automatic)           │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Interactions (List View)**

- Tap "+ New Plan" -> Show a menu or navigate to a screen to choose plan type: "Goal-based Plan" or "Regular Saving Plan".
- Tap a plan -> Navigate to Plan Detail Screen.

**Visual Layout (Plan Creation/Edit Screen - Combined)**

A tabbed or segmented control interface could be used to switch between creating a goal-based plan and a recurring saving plan.

**Tab 1: Goal-Based Plan (InvestmentPlan)**

```
┌──────────────────────────────────────────────────┐
│  ✕ Cancel       New Goal-Based Plan         Save │
├──────────────────────────────────────────────────┤
│                                                  │
│  Plan Name *                                     │
│  [ Retirement 2050 ]                             │
│                                                  │
│  Target Amount (Optional)                        │
│  [ $1,000,000.00 ]                               │
│                                                  │
│  Target Date (Optional)                          │
│  [ 2050-01-01 📅 ]                               │
│                                                  │
│  Monthly Contribution (Optional)                 │
│  [ $500.00 ]                                     │
│                                                  │
│  Risk Tolerance *                                │
│  [ Moderate ▼ ]                                  │
│                                                  │
└──────────────────────────────────────────────────┘
```

**Tab 2: Regular Saving Plan (RegularSavingPlan)**

```
┌──────────────────────────────────────────────────┐
│  ✕ Cancel      New Regular Saving Plan      Save │
├──────────────────────────────────────────────────┤
│                                                  │
│  Plan Name *                                     │
│  [ Monthly S&P 500 Plan ]                        │
│                                                  │
│  Source of Funds (Optional)                      │
│  [ Cash (USD) ▼ ]                                │
│  <If empty, treated as a deposit/transfer>       │
│                                                  │
│  Asset to Invest In *                            │
│  [ Vanguard S&P 500 (VOO) ▼ ]                    │
│                                                  │
│  Investment Amount *                             │
│  [ $100.00 ]                                     │
│                                                  │
│  Frequency *                                     │
│  [ Weekly ▼ ]                                    │
│                                                  │
│  Start Date *                                    │
│  [ Oct 10, 2025 📅 ]                             │
│                                                  │
│  Execution Method *                              │
│  ( ) Automatic (Create transaction for me)       │
│  (◉) Manual (Remind me to create it)             │
│                                                  │
└──────────────────────────────────────────────────┘
```

______________________________________________________________________

## Navigation Structure

### macOS Navigation

**Pattern**: Sidebar + Detail View (Multi-column)

```
┌─────────────────────┬──────────────────────────────────┐
│  Sidebar            │  Detail View                     │
│                     │                                  │
│  Overview           │  [Content for selected item]     │
│                     │                                  │
│  PORTFOLIOS         │                                  │
│  Tech Stocks        │                                  │
│  Real Estate        │                                  │
│  Crypto             │                                  │
└─────────────────────┴──────────────────────────────────┘
```

**Current Implementation (Phase 1 MVP)**:

- ✅ Overview (default landing page)
  - Shows total portfolio value and count
  - Lists all portfolios with their values and asset counts
  - Add Portfolio button in toolbar
- ✅ Individual Portfolio Items in Sidebar
  - Each portfolio appears in sidebar
  - Click to view portfolio detail (assets, total value, subtitle with description)
  - Right-click portfolio for Edit and Delete context menu
- 🚧 Assets section (Future)
- 🚧 Plans section (Future)
- 🚧 Settings (Future)

**User Flow**

1. App opens to Overview (shows all portfolios summary)
1. Click "Add Portfolio" button in Overview toolbar → Create new portfolio
1. Click portfolio in sidebar → View portfolio detail with assets
1. Right-click portfolio in sidebar → Edit or Delete portfolio

**Context Menu Actions (Sidebar Portfolios)**:

- Right-click any portfolio item in sidebar
- Menu shows:
  - "Edit Portfolio" → Opens edit form in sheet/popup
  - "Delete Portfolio" → Validates and shows confirmation/error
- Portfolio must be empty (no assets) to delete

______________________________________________________________________

### iOS Navigation

**Pattern**: Tab Bar + Navigation Stack

```
Screen Content

─────────────────────────────────────────
[ Assets ] [ Portfolios ] [ Plans ] [ More ]
```

**Tabs**

1. **Assets**: Asset list → Asset detail → Edit
1. **Portfolios**: Portfolio list → Portfolio detail → Asset detail
1. **Plans**: Investment plans (Phase 3)
1. **More**: Settings, about, etc.

**User Flow**

- Switch tabs to access major sections
- Tap items to drill down (navigation stack)
- Use navigation bar buttons for actions
- Modal sheets for entry/edit forms

______________________________________________________________________

### iPadOS Navigation

**Pattern**: Adaptive (Sidebar in landscape, Tabs in portrait)

- Landscape/Regular width: Same as macOS (sidebar)
- Portrait/Compact width: Same as iOS (tab bar)

______________________________________________________________________

## Visual Style

### Color Usage

**Semantic Colors** (leverage system defaults)

- **Accent**: Primary actions and highlights (system blue)
- **Positive**: Gains, increases (green)
- **Negative**: Losses, decreases (red)
- **Neutral**: Informational, no change (gray)

**Background Hierarchy**

- Primary background: `.background`
- Cards/grouped content: `.secondaryBackground` or subtle fill
- Elevated elements: Shadow or border for depth

**Automatic Dark Mode**

- Use semantic color names
- Test all screens in both light and dark mode
- Ensure sufficient contrast in both modes

______________________________________________________________________

### Typography

**Hierarchy** (using system text styles)

- **Screen Titles**: Large, bold (`.title` or `.largeTitle`)
- **Section Headers**: Medium, bold (`.title2` or `.title3`)
- **Primary Content**: Regular weight (`.body`)
- **Secondary Info**: Smaller, gray (`.subheadline` or `.caption`)
- **Financial Values**: Monospaced digits for alignment

**Formatting Rules**

- Currency: Always use `Decimal` type with `.formatted(currency:)` extension
- Percentages: Use `.formattedPercentage()` extension
- Large numbers: Auto-format with K, M suffixes in compact contexts

______________________________________________________________________

### Iconography

**SF Symbols** (system icon library)

**Asset Type Icons**

- Stocks: `chart.line.uptrend.xyaxis`
- Bonds: `doc.text`
- Cryptocurrency: `bitcoinsign.circle`
- Real Estate: `house`
- Cash: `dollarsign.circle`
- Other: `folder`

**Action Icons**

- Add: `plus.circle.fill`
- Edit: `pencil`
- Delete: `trash`
- Save: `checkmark`
- Cancel: `xmark`

**Chart Icons**

- Pie chart: `chart.pie.fill`
- Line chart: `chart.xyaxis.line`
- Performance: `arrow.up.right` (gain) / `arrow.down.right` (loss)

**Icon Style**

- Use filled variants for primary actions
- Outline variants for secondary actions
- Consistent sizing within context (toolbar vs inline)

______________________________________________________________________

### Spacing and Layout

**Grid System**: 8pt base unit

- Small spacing: 8pt
- Medium spacing: 16pt
- Large spacing: 24pt
- Extra large: 32pt

**Content Width**

- Maximum readable width for text: ~600pt
- Cards: Full width with margins or max width in larger viewports
- Lists: Full width within safe areas

**Card Design**

- Background: Secondary background or subtle border
- Padding: 16pt internal padding
- Corner radius: 10-12pt
- Shadow: Subtle (optional, avoid in dark mode)

______________________________________________________________________

### Component Patterns

**List Rows**

- Primary text: Asset name or title
- Secondary text: Type, category, or description
- Trailing content: Value, performance, accessory
- Swipe actions (iOS): Edit, Delete

**Cards**

- Used for summarized information (portfolio summary, value cards)
- Clear visual separation from background
- Consistent padding and corner radius

**Forms**

- Grouped style (platform default)
- Clear section headers
- Inline validation messages
- Distinct focus states

**Empty States**

- Centered icon (large, friendly)
- Brief message (1-2 sentences)
- Clear call-to-action button
- Encouraging tone

**Loading States**

- Progress spinner for operations < 5 seconds
- Skeleton screens for content loading
- Explicit "Loading..." text for clarity

**Error States**

- Error icon (⚠️ or `exclamationmark.triangle`)
- Clear error message
- Suggested action or retry button
- Non-blocking where possible

______________________________________________________________________

## Platform-Specific Design Adaptations

### macOS

**Visual Characteristics**

- Larger minimum window size (800×600pt)
- Toolbar with icon + label buttons
- Multi-window support (future)
- Hover states on interactive elements

**Interaction Patterns**

- Right-click context menus
- Keyboard shortcuts (⌘N for new, ⌘S for save, etc.)
- Drag and drop (future enhancement)
- Double-click to open detail views

______________________________________________________________________

### iOS

**Visual Characteristics**

- Full screen, safe area aware
- Navigation bar with large titles
- Tab bar at bottom
- Touch-optimized tap targets (min 44×44pt)

**Interaction Patterns**

- Swipe to go back (navigation stack)
- Swipe actions on list rows
- Pull to refresh (future)
- Long press for context menus
- Modal sheets for forms

______________________________________________________________________

### iPadOS

**Visual Characteristics**

- Combines macOS and iOS patterns
- Sidebar when space available
- Pointer support (hover states)
- Multi-window and split view support

**Interaction Patterns**

- All iOS touch gestures
- Keyboard shortcuts (when keyboard connected)
- Trackpad/mouse support
- Drag and drop between views (future)

______________________________________________________________________

## Accessibility Considerations

### Visual Accessibility

- **Contrast**: Use semantic colors (automatically meet WCAG AA)
- **Text Scaling**: Support Dynamic Type (all text should scale)
- **Reduce Motion**: Provide non-animated alternatives

### Screen Reader (VoiceOver)

- All interactive elements have clear labels
- Images and icons have descriptive labels
- Logical reading order (top to bottom, left to right)
- Actionable items clearly identified

### Keyboard Navigation

- Full keyboard navigation on macOS
- Logical tab order
- Visible focus indicators
- Keyboard shortcuts for common actions

### Touch Accessibility

- Minimum touch target: 44×44pt (iOS)
- Sufficient spacing between interactive elements
- Swipe gestures have alternative methods (button equivalents)

______________________________________________________________________

# Part 2: Implementation Guide

## SwiftUI Implementation Patterns

### Asset List Screen Implementation

**Primary Views**

```swift
// Use NavigationSplitView (macOS) or NavigationStack (iOS)
// List with @Query for automatic SwiftData integration
// .searchable() modifier for search functionality
```

**Key Components**

- `@Query` for asset list
- `NavigationLink` for row navigation
- `.toolbar` for Add button
- `.swipeActions` for iOS quick actions

______________________________________________________________________

### Asset Detail Screen Implementation

**Layout Structure**

```swift
// ScrollView or Form with VStacks
// Group related information in cards (VStack + background)
// Use @Binding or @State for edit mode
```

**Data Flow**

- Pass selected asset via navigation
- Use `@Bindable` for editing
- No manual save needed (SwiftData auto-persists)

______________________________________________________________________

### Transaction Entry Implementation

**Form Structure**

```swift
// Form with sections
// Pickers for type and asset selection
// DatePicker for transaction date
// TextField with number formatting for decimals
// Validation logic with @State
```

**Validation**

- Use `@State` for form fields
- Computed property for form validity
- Disable save button until valid
- Show error text near invalid fields

______________________________________________________________________

### Portfolio Detail Implementation

**Chart Integration**

```swift
// Use Swift Charts framework
// Pie chart or donut chart for allocation
// Computed data from portfolio.assets relationship
```

**Data Aggregation**

- Use portfolio's `totalValue` computed property
- Calculate allocation percentages from asset types
- Group assets by type for chart data

______________________________________________________________________

## Reusable Components

### CurrencyText

**Purpose**: Consistently formatted currency display

**Usage**: Use `Decimal.formatted(currency:)` extension from `Utilities/Extensions.swift`

**Example Pattern**

```swift
Text(asset.currentValue.formatted(currency: "USD"))
    .font(.title2)
    .fontWeight(.semibold)
```

______________________________________________________________________

### PercentageText

**Purpose**: Formatted percentage with color coding

**Pattern**

```swift
// Use formattedPercentage() extension
// Apply color based on positive/negative
let percentage: Decimal = 0.052
Text(percentage.formattedPercentage())
    .foregroundColor(percentage >= 0 ? .green : .red)
```

______________________________________________________________________

### AssetTypeIcon

**Purpose**: Consistent SF Symbol icon for asset types

**Pattern**

```swift
// Map asset type string to SF Symbol name
func icon(for assetType: String) -> String {
    switch assetType {
    case "Stock": return "chart.line.uptrend.xyaxis"
    case "Cryptocurrency": return "bitcoinsign.circle"
    case "Real Estate": return "house"
    // etc.
    }
}
```

______________________________________________________________________

### ValueCard

**Purpose**: Card-style container for metrics

**Pattern**

```swift
VStack(alignment: .leading, spacing: 8) {
    Text("Total Value")
        .font(.subheadline)
        .foregroundColor(.secondary)
    Text(value.formatted(currency: "USD"))
        .font(.title)
        .fontWeight(.bold)
}
.padding()
.background(Color(.secondarySystemBackground))
.cornerRadius(10)
```

______________________________________________________________________

### EmptyStateView

**Purpose**: Placeholder when no data exists

**Pattern**

```swift
VStack(spacing: 16) {
    Image(systemName: "chart.bar")
        .font(.system(size: 64))
        .foregroundColor(.secondary)
    Text("No assets yet")
        .font(.title2)
    Text("Add your first asset to get started")
        .font(.body)
        .foregroundColor(.secondary)
    Button("Add Asset") { /* action */ }
        .buttonStyle(.borderedProminent)
}
.padding()
```

______________________________________________________________________

## Platform-Specific Code

### macOS-Specific

```swift
#if os(macOS)
.frame(minWidth: 800, minHeight: 600)
.toolbar {
    ToolbarItem(placement: .primaryAction) {
        Button("Add Asset", systemImage: "plus") { /* action */ }
    }
}
#endif
```

______________________________________________________________________

### iOS-Specific

```swift
#if os(iOS)
.navigationBarTitleDisplayMode(.large)
.sheet(isPresented: $showingAddAsset) {
    AddAssetView()
}
.swipeActions {
    Button("Delete", role: .destructive) { /* action */ }
}
#endif
```

______________________________________________________________________

### Adaptive (iPadOS)

```swift
// Use NavigationSplitView, automatically adapts
NavigationSplitView {
    // Sidebar content
} detail: {
    // Detail content
}
// Becomes sidebar in regular width, tabs in compact
```

______________________________________________________________________

## Development Workflow

### Before Building a Screen

1. **Define Purpose**: Write one sentence describing the screen's goal
1. **Identify Data**: Which models/queries are needed?
1. **Sketch Layout**: Quick sketch or mental model of sections
1. **Choose Container**: List, Form, ScrollView, or custom layout?
1. **Plan Navigation**: How do users arrive and leave?

______________________________________________________________________

### While Building

1. Use **Xcode Previews** for rapid iteration
1. Test with **realistic data** (multiple items, edge cases)
1. Check **light and dark mode**
1. Verify **Dynamic Type** scaling
1. Test on **multiple simulators** (iPhone, iPad, macOS)

______________________________________________________________________

### After Implementation

1. Add **empty states**
1. Add **loading states** (if async)
1. Add **error handling UI**
1. Verify **keyboard navigation** (macOS)
1. Check **touch targets** (iOS: min 44×44pt)
1. Test **VoiceOver** (basic navigation)

______________________________________________________________________

## Accessibility Implementation

### Quick Wins

**Accessibility Labels**

```swift
Image(systemName: "plus.circle.fill")
    .accessibilityLabel("Add asset")
```

**Accessibility Hints**

```swift
Button("Edit") { /* action */ }
    .accessibilityHint("Edit this asset's information")
```

**Dynamic Type**

- Use system text styles (`.title`, `.body`, etc.)
- Automatic support, no extra work needed

**Color Coding**

- Don't rely on color alone
- Use icons or text along with color (e.g., ↗ + green for gains)

______________________________________________________________________

### Testing Accessibility

**VoiceOver** (Screen Reader)

- macOS: Cmd+F5 to toggle
- iOS: Settings → Accessibility → VoiceOver
- Test: Navigate entire screen without looking

**Dynamic Type**

- iOS: Settings → Display & Text Size → Larger Text
- Test: Read content at largest size

**Reduce Motion**

- iOS: Settings → Accessibility → Motion → Reduce Motion
- Ensure animations have static alternatives

______________________________________________________________________

## Performance Considerations

### SwiftData Queries

- Use predicates to filter queries (avoid loading everything)
- Limit relationship traversal depth
- Use batch fetches for large lists

### View Performance

- Extract subviews to keep view body small
- Use `@Query` instead of manual fetching
- Avoid heavy computation in view body (use computed properties on models)

______________________________________________________________________

## Design Evolution Strategy

### When to Refine

Refine UI when you encounter:

1. **Friction**: Repeated struggle with a task
1. **Confusion**: Unclear what action to take
1. **Inefficiency**: Too many steps for common tasks
1. **Visual noise**: Hard to find information
1. **Inconsistency**: Similar tasks feel different

### Refinement Process

1. Identify specific pain point
1. Sketch alternative approach
1. Implement in code (small iterations)
1. Test with real usage
1. Document decision (if significant)

### Avoid Over-Engineering

- Don't polish rarely-used screens
- Don't add speculative features
- Don't obsess over pixels early
- Focus on daily-use workflows

______________________________________________________________________

## Resources

### Apple Documentation

- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SF Symbols App](https://developer.apple.com/sf-symbols/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Swift Charts](https://developer.apple.com/documentation/charts)

### Learning Resources

- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Accessibility Guidelines](https://developer.apple.com/accessibility/)

______________________________________________________________________

**Document Status**: 🚧 Initial framework - update as screens are designed and built

**Last Updated**: 2025-10-09

**Next Action**: Implement Asset List Screen (Phase 1 MVP), update this doc with actual design decisions
