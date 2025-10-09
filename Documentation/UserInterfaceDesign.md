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

### Phase 4: Polish

**Goal**: Refined user experience

**Focus**: Dark mode optimization, accessibility, error states, platform-specific enhancements

______________________________________________________________________

## Screen Designs

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
│  📈  Apple Inc. (AAPL)                          │
│      Stock • Portfolio: Tech                     │
│      $1,250.00               +5.2% ↗            │
│                                                  │
│  🪙  Bitcoin                                     │
│      Cryptocurrency • Portfolio: Crypto          │
│      $4,500.00               -2.1% ↘            │
│                                                  │
│  🏠  Rental Property                             │
│      Real Estate • Unassigned                    │
│      $250,000.00             +0.3% ↗            │
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
- Swipe row (iOS) → Quick actions (Edit, Delete)

**Empty State**

- Icon: 📊 chart icon
- Message: "No assets yet"
- Action: "Add your first asset" button

______________________________________________________________________

### Asset Detail Screen

**Primary Purpose**: View and edit complete asset information

**Visual Layout**

```
┌──────────────────────────────────────────────────┐
│  ← Assets                              [Edit]    │
├──────────────────────────────────────────────────┤
│                                                  │
│  📈 Apple Inc. (AAPL)                           │
│  Stock                                           │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │  Current Value                             │ │
│  │  $1,250.00                                 │ │
│  │                                            │ │
│  │  Quantity: 10 shares                       │ │
│  │  Avg. Cost: $110.00/share                  │ │
│  │  Total Cost: $1,100.00                     │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │  Performance                               │ │
│  │                                            │ │
│  │  Unrealized Gain                           │ │
│  │  +$150.00   (+13.6%) ↗                    │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  Recent Transactions                             │
│                                                  │
│  Buy     10 shares @ $110.00    Jan 15, 2025    │
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
│  [ Apple Inc. (AAPL) ▼ ]                        │
│                                                  │
│  Date *                                          │
│  [ Jan 15, 2025 📅 ]                            │
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
│  [ _________________________________ ]            │
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

### Portfolio Detail Screen

**Primary Purpose**: View portfolio composition and allocation

**Visual Layout**

```
┌──────────────────────────────────────────────────┐
│  ← Portfolios                          [Edit]    │
├──────────────────────────────────────────────────┤
│                                                  │
│  Tech Portfolio                                  │
│                                                  │
│  Total Value: $15,750.00                         │
│  Return: +$1,250.00 (+8.6%)                     │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │    Asset Allocation                        │ │
│  │                                            │ │
│  │         ╱───────╲                          │ │
│  │        │  Chart  │                         │ │
│  │         ╲───────╱                          │ │
│  │                                            │ │
│  │  ■ Stocks 65%      ■ Crypto 25%           │ │
│  │  ■ Bonds 10%                              │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  Holdings                                        │
│                                                  │
│  📈 Apple Inc.         $1,250.00    8%   +5.2%  │
│  📈 Microsoft Corp.    $2,100.00   13%   +3.1%  │
│  🪙 Bitcoin           $4,500.00   29%   -2.1%  │
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

- Tap "Edit" → Edit portfolio details (name, target allocation)
- Tap asset row → Navigate to asset detail
- Tap "Add Asset" → Add existing asset or create new one

**Chart Colors** (Phase 2+)

- Use distinct, accessible colors for asset types
- Include legend with percentages

______________________________________________________________________

### Dashboard Screen (Phase 2)

**Primary Purpose**: Overview of all portfolios and total wealth

**Visual Layout**

```
┌──────────────────────────────────────────────────┐
│  Dashboard                                       │
├──────────────────────────────────────────────────┤
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │  Total Portfolio Value                     │ │
│  │  $45,230.00                                │ │
│  │  +$3,120.00 (+7.4%) this month            │ │
│  └────────────────────────────────────────────┘ │
│                                                  │
│  ┌────────────────────────────────────────────┐ │
│  │  Overall Allocation                        │ │
│  │  [Pie Chart across all portfolios]         │ │
│  └────────────────────────────────────────────┘ │
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

## Navigation Structure

### macOS Navigation

**Pattern**: Sidebar + Detail View (Multi-column)

```
┌─────────────┬──────────────────────────────────┐
│  Sidebar    │  Detail View                     │
│             │                                  │
│  Dashboard  │  [Content for selected item]     │
│  Assets     │                                  │
│  Portfolios │                                  │
│  Plans      │                                  │
│  Settings   │                                  │
└─────────────┴──────────────────────────────────┘
```

**User Flow**

1. Select section in sidebar (e.g., "Assets")
1. View list or detail in main area
1. Double-click or select item for detail view
1. Use toolbar actions for Add/Edit/Delete

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
