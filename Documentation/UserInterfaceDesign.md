# User Interface Design

## Preface

**Purpose of this Document**

This document describes the user interface design for AssetFlow -- **what** users see and **how** they interact with the macOS desktop application. It is separated into two main parts:

1. **Design Specification** -- Visual design, user experience, and interaction patterns
1. **Implementation Guide** -- Technical notes for building the designs in SwiftUI

**Design Philosophy**

- **Iterate in code**: Use Xcode previews instead of separate mockup tools
- **Leverage platform defaults**: Start with native SwiftUI components
- **macOS-native**: Follow Apple's Human Interface Guidelines for macOS
- **Prioritize functionality**: Working features before visual polish

**Related Documentation**

- [BusinessLogic.md](BusinessLogic.md) - Calculations and business rules
- [DataModel.md](DataModel.md) - Data structures
- [Architecture.md](Architecture.md) - MVVM layer responsibilities

______________________________________________________________________

# Part 1: Design Specification

## Navigation Structure

The app uses a **sidebar navigation** layout (standard macOS pattern):

**Sidebar items**:

1. **Dashboard** -- Portfolio overview (default/home screen)
1. **Snapshots** -- Chronological snapshot management
1. **Assets** -- Asset registry and category assignment
1. **Categories** -- Category management with target allocations
1. **Platforms** -- Platform management (rename)
1. **Rebalancing** -- Rebalancing calculator
1. **Import** -- CSV import workflow

**Detail views**: Each sidebar section with a list-detail pattern (Snapshots, Assets, Categories, Platforms) uses a **list-detail split** within the content area. The list appears on the leading side and the detail view on the trailing side. When no item is selected, the detail area shows a placeholder prompt (e.g., "Select a snapshot to view details").

**Dashboard, Rebalancing, and Import** occupy the full content area without a list-detail split.

**Toolbar**:

- Import button (opens the same import flow as the sidebar Import item)

______________________________________________________________________

## Dashboard (Home Screen)

The dashboard provides a portfolio overview using the latest snapshot (with carry-forward).

**Layout**:

1. **Summary cards row**:

   - Total Portfolio Value (with change from previous snapshot, absolute and percentage)
   - Latest Snapshot Date
   - Number of Assets
   - Cumulative TWR (since first snapshot)
   - CAGR (since first snapshot) -- shown alongside Cumulative TWR, with a tooltip: "CAGR is the annualized rate at which the portfolio's total value has grown since inception, including the effect of deposits and withdrawals. TWR measures pure investment performance by removing cash flow effects."
   - Each metric card (Total Portfolio Value, TWR, CAGR, Growth, Return) includes an info icon/tooltip explaining what the metric measures and how it differs from related metrics

1. **Period performance cards**:

   - **Growth Rate** card -- simple percentage change with 1M / 3M / 1Y segmented control. Shows "N/A" if insufficient history.
   - **Return Rate** card -- Modified Dietz return with 1M / 3M / 1Y segmented control. Shows "N/A" if insufficient history.
   - Each card includes an info icon/tooltip explaining the metric

1. **Allocation pie chart**:

   - Category allocation with a **snapshot date picker** (defaults to latest snapshot)
   - Shows percentage and value for each category
   - Clicking a category navigates to category detail

1. **Portfolio value line chart**:

   - Total portfolio value over all snapshots
   - Time axis with snapshot dates
   - Time range zoom controls

1. **Cumulative TWR line chart**:

   - Portfolio-level cumulative time-weighted return over time
   - Shows "Insufficient data (need at least 2 snapshots)" when fewer than 2 snapshots

1. **Recent snapshots list**:

   - Last 5 snapshots (newest first) with date, total value, and import summary
   - "View all" link navigates to Snapshots screen
   - Each row is clickable and navigates to snapshot detail

______________________________________________________________________

## Snapshots Screen

**List view**:

- Chronological list of all snapshots (newest first)
- Each row: date, total value (composite), platforms included, number of assets
- Carried-forward indicators: visual marker showing imported vs. carried-forward platforms
- "New Snapshot" button

**New Snapshot creation flow**:

1. User clicks "New Snapshot"
1. Date picker appears (future dates disabled)
1. If the selected date already has a snapshot, show validation error: "A snapshot already exists for [date]. Go to the Snapshots screen to view and edit it."
1. Starting point selector:
   - **Start empty**: Creates snapshot with no asset entries
   - **Copy from latest**: Pre-populates with all assets from the most recent prior snapshot's composite view (materializes carried-forward values as direct SnapshotAssetValues). Disabled (grayed out with explanatory text) when no snapshots exist before the selected date.
1. On creation, user is taken to the snapshot detail view for editing

**Snapshot detail view** (on selection):

- Full asset breakdown table sorted by platform (alphabetical), then by asset name (alphabetical)
- Columns: Asset Name, Platform, Category, Market Value
- Carried-forward values visually distinguished (e.g., dimmed or labeled)
- Category allocation summary for this snapshot
- Cash flow operations table: Description, Amount
- Net cash flow summary line
- Actions: Add asset, Edit values, Remove asset, Delete snapshot, Add cash flow, Edit cash flow, Remove cash flow

**Add asset to snapshot**: Two paths:

1. **Select existing asset**: Autocomplete search by name. When selected, platform and category are read-only (inherited from asset record). Rejected if the asset already exists in this snapshot.
1. **Create new asset**: Enter name, select platform (picker includes a "New Platform..." option), select category (picker includes a "New Category..." option). Creates the asset record and adds it to the snapshot.

**Edit value**: Click on market value to edit inline. Changes are saved immediately. There is no undo for inline value edits. Users should verify values before moving to the next field.

**Remove asset from snapshot**: Confirmation dialog: "Remove [Asset Name] from this snapshot? The asset record itself will not be deleted."

**Delete snapshot**: Confirmation dialog: "Delete snapshot from [date]? This will remove all [N] asset values and [M] cash flow operations. This action cannot be undone."

______________________________________________________________________

## Assets Screen

**List view**:

- All known assets, grouped by platform (default) or category, switchable via **segmented control**
- Sort order: alphabetical by asset name within each group
- When grouped by platform, assets without a platform appear under "(No Platform)" at the end
- When grouped by category, assets without a category appear under "(Uncategorized)" at the end
- Each row: Asset Name, Platform, Category, Latest Value
- Latest value comes from the most recent composite snapshot (including carry-forward)
- Assets with no snapshot values show "\\u{2014}" for value

**Asset detail view**:

- Value history across snapshots (table and sparkline -- a compact inline line chart for quick trend recognition, non-interactive)
- Value history shows only directly recorded values (no carry-forward)
- Asset name (editable)
- Platform (editable via picker with existing platforms + "New Platform..." option)
- Category assignment (editable via picker with existing categories + "None" option)
- Changes save immediately on field change
- Renaming an asset updates it retroactively across all snapshots (single record update)
- Duplicate identity validation: (name, platform) must be unique (case-insensitive, trimmed, collapsed)
- Delete action: **only enabled when asset has no SnapshotAssetValue records**. When disabled, shows: "This asset cannot be deleted because it has values in snapshot(s). Remove the asset from all snapshots first."

### Implementation Notes (Phase 2)

- **AssetListView** (`AssetFlow/Views/AssetListView.swift`): Uses `AssetListViewModel` with `@State`. Segmented control binds to `viewModel.groupingMode`. List sections iterate over `viewModel.groups`. Context menu on rows provides delete action for eligible assets.
- **AssetDetailView** (`AssetFlow/Views/AssetDetailView.swift`): Uses `AssetDetailViewModel` with `@State`. Form with `.grouped` style. Platform picker uses `Binding<String>` with sentinel `"__new__"` for inline new-platform creation. Sparkline uses Swift Charts `LineMark` with hidden axes, 40pt height. Delete confirmation dialog before deletion.
- **AssetListViewModel** (`AssetFlow/ViewModels/AssetListViewModel.swift`): Groups assets by platform or category. Computes latest values via `CarryForwardService.compositeValues()` from the most recent snapshot. "(No Platform)" and "(Uncategorized)" groups always sorted last.
- **AssetDetailViewModel** (`AssetFlow/ViewModels/AssetDetailViewModel.swift`): Editable fields (`editedName`, `editedPlatform`, `editedCategory`) initialized from asset. `save()` validates normalized identity uniqueness. `loadValueHistory()` returns direct SAVs sorted chronologically.

______________________________________________________________________

## Categories Screen

**List view**:

- All categories listed alphabetically
- Each row: name, target allocation %, current allocation %, current value, asset count
- Visual indicator when current allocation deviates significantly from target
- Add/edit/delete category actions

**Category detail view**:

- Assets in this category
- Value history over snapshots (line chart)
- Allocation percentage history over snapshots (line chart)

**Cross-section navigation**: Clicking a category in the dashboard pie chart navigates to the Categories section in the sidebar and selects the clicked category, showing its detail view. This is a cross-section navigation action (Dashboard -> Categories).

**Implementation notes (Phase 3)**:

- **CategoryListView** (`AssetFlow/Views/CategoryListView.swift`): Takes `modelContext` and `selectedCategory: Binding<Category?>`. Uses `@State private var viewModel: CategoryListViewModel`. List selection drives the binding. Toolbar "+" button opens add category sheet. Target allocation sum warning banner shown at top when allocations don't sum to 100%. Deviation indicator (orange `exclamationmark.triangle.fill`) shown when `abs(current - target) > 5`. Empty state uses folder icon.
- **CategoryListViewModel** (`AssetFlow/ViewModels/CategoryListViewModel.swift`): `CategoryRowData` struct bundles category, target/current allocation, value, and asset count. `loadCategories()` batch-fetches all data and uses `CarryForwardService.compositeValues` for the latest snapshot. `createCategory`/`editCategory`/`deleteCategory` with validation via `CategoryError`.
- **CategoryDetailView** (`AssetFlow/Views/CategoryDetailView.swift`): Takes `category`, `modelContext`, `onDelete`. Parent must apply `.id(category.id)` for proper state reset. Form sections: Category Details (name + target allocation), Assets in Category (Table), Value History (LineMark + PointMark chart), Allocation History (LineMark + PointMark chart), Danger Zone (delete button).
- **CategoryDetailViewModel** (`AssetFlow/ViewModels/CategoryDetailViewModel.swift`): `editedName`/`editedTargetAllocation` initialized from category. `loadData()` computes asset list with latest values, value history, and allocation history across all snapshots using `CarryForwardService`. Single snapshot renders as PointMark only.

______________________________________________________________________

## Platforms Screen

**List view**:

- All platforms listed alphabetically
- Each row: Platform name, number of assets, total latest value

**Platform detail view** (on selection):

- List of all assets on this platform with their latest market values
- Total value across all assets on this platform
- Platform name (editable)

**Actions**:

- **Rename**: Change platform name. Updates all assets. New name must not conflict (case-insensitive).
- **Delete**: Implicit -- when all assets are moved away, platform no longer appears.

Assets with no platform are NOT shown on the Platforms screen.

______________________________________________________________________

## Rebalancing Screen

- Current allocation vs. target allocation table
- For each category: current value, current %, target %, difference ($), action (buy/sell amount)
- Sort order: by absolute adjustment magnitude (largest deviation first)
- Summary of suggested moves
- Read-only/preview -- no data modification occurs
- Only categories with a target allocation are included
- Uncategorized assets shown as separate row with "--" for Target % and "N/A" for Action

______________________________________________________________________

## Import Screen

See [BusinessLogic.md](BusinessLogic.md) for the detailed CSV import flow.

**Layout**:

- **Import type selector**: Segmented control (Assets | Cash Flows), defaults to Assets
- **File selector**: Drag-and-drop zone or "Browse" button (filtered to `.csv`)
- **Expected schema display**: Show the expected CSV column names for the selected import type and provide downloadable sample CSVs
- **Configuration** (after file selected):
  - Asset import: Snapshot date picker (future dates disabled), Platform picker, Category picker
  - Cash flow import: Snapshot date picker (future dates disabled)
- **Preview table**: Parsed data with validation indicators and per-row remove buttons
  - If an asset already exists with a different category than the import-level category, a warning indicator is shown on that row
- **Validation summary**: Errors (red) and warnings (yellow)
- **Import button**: Disabled if validation errors exist
- **On successful import**: Snapshot is created (or updated if one exists for that date); user is navigated to the snapshot detail view

If user navigates away (including sidebar navigation) with file loaded but not imported, confirmation dialog: "Discard import? The selected file has not been imported yet."

______________________________________________________________________

## Empty States

| Screen      | Empty State                                                                                                                 |
| ----------- | --------------------------------------------------------------------------------------------------------------------------- |
| Dashboard   | Welcome message, prominent "Import your first CSV" button, brief workflow explanation                                       |
| Snapshots   | "No snapshots yet. Create your first snapshot or import a CSV to get started." with "New Snapshot" and "Import CSV" buttons |
| Assets      | "No assets yet. Assets are created automatically when you import CSV data."                                                 |
| Categories  | "No categories yet. Create categories to organize your assets and set target allocations." with "Create Category" button    |
| Platforms   | "No platforms yet. Platforms are created automatically when you import CSV data or create assets."                          |
| Rebalancing | "Set target allocations on your categories to use the rebalancing calculator."                                              |

______________________________________________________________________

## Settings

Accessible via menu bar (AssetFlow > Settings) or Cmd+,.

**Settings options**:

1. **Display currency**: Currency code (e.g., USD, TWD, EUR). Display-only, no FX conversion.
1. **Date format**: Picker with Swift `Date.FormatStyle` options (`.numeric`, `.abbreviated`, `.long`, `.complete`). Default: system locale or `.abbreviated`.
1. **Default platform**: Pre-filled platform value during import (can be overridden per import). Default: empty.
1. **Data Management**:
   - **Export Backup**: Exports all data to ZIP archive. User selects save location. Default filename: `AssetFlow-Backup-YYYY-MM-DD.zip`.
   - **Restore from Backup**: Imports backup archive. Confirmation: "Restoring from backup will replace ALL existing data. This cannot be undone. Continue?" Validates file integrity (CSV presence, headers, foreign key references). On failure, shows detailed error. On success, reloads all views.

______________________________________________________________________

## Keyboard Shortcuts

| Shortcut | Action                                          |
| -------- | ----------------------------------------------- |
| Delete   | Remove selected item (with confirmation dialog) |

Additional shortcuts (Cmd+I, Cmd+N, etc.) deferred to future version.

______________________________________________________________________

## Window and Appearance

- **Minimum window size**: 900 x 600 points
- **Sidebar**: Collapsible via toolbar button or drag. Default width: 220 points.
- **Appearance**: Supports system appearance (light and dark mode). All custom colors, chart colors, and carry-forward indicators adapt to both modes.

**Number formatting**:

- Monetary values: Full stored precision with thousand separators (e.g., $1,234.5, $28,000). No minimum or maximum decimal places are enforced -- values display exactly as entered or computed.
- Percentages: 2 decimal places (e.g., 45.23%)
- Chart axes: Abbreviated for large values (K, M, B)

Allocation percentage totals display actual sum (no forced normalization to 100%).

______________________________________________________________________

## Visualizations

### Time Range Controls

All line charts include a zoom selector:

- 1W, 1M, 3M, 6M, 1Y, 3Y, 5Y, All
- Default: All
- Shows only snapshots within selected range
- "No data for selected period" if empty
- Range resets to "All" when navigating away (not persisted)

### Pie Chart -- Category Allocation (Section 12.1)

- Shows allocation at a selected snapshot (default: latest)
- Each slice = one category
- Slices sorted by value (largest first, clockwise from 12 o'clock)
- Uncategorized shown as distinct slice (uses a neutral/gray tone to indicate it is not a user-defined category)
- Labels: category name, percentage, value
- Hover: tooltip with details. Click: navigates to category detail.

### Line Chart -- Portfolio Value Over Time (Section 12.2)

- X-axis: snapshot dates. Y-axis: composite total value.
- Data points at each snapshot
- Hover: tooltip with date and value. Click: navigates to snapshot detail.
- Time range zoom controls

### Line Chart -- Category Value Over Time (Section 12.3)

- Multiple lines, one per category
- Legend with category names
- Toggle individual categories on/off
- Hover: tooltip with date, category name, value. No click-to-navigate.
- Time range zoom controls

Category detail also includes allocation percentage line chart (same format, single category).

### Cumulative TWR Chart (Section 12.4)

- X-axis: snapshot dates. Y-axis: cumulative TWR (%)
- Portfolio-level return over time
- Hover: tooltip with date and TWR percentage. No click-to-navigate.
- Time range zoom controls

### Chart Empty and Edge States

| Chart                  | Condition                                | Display                                         |
| ---------------------- | ---------------------------------------- | ----------------------------------------------- |
| Pie chart              | All assets uncategorized                 | Single slice "Uncategorized" 100%               |
| Pie chart              | No assets in latest snapshot             | "No asset data available"                       |
| Line chart (portfolio) | Only one snapshot                        | Single data point with label, no line           |
| Line chart (portfolio) | No snapshots in range                    | "No data for selected period"                   |
| Line chart (category)  | No categories defined                    | "Create categories to see allocation trends"    |
| Line chart (category)  | Category has zero value in all snapshots | Omit from chart, show "(no data)" in legend     |
| TWR chart              | Fewer than 2 snapshots                   | "Insufficient data (need at least 2 snapshots)" |
| TWR chart              | All returns N/A in range                 | "Cannot calculate returns for selected period"  |

______________________________________________________________________

## Visual Style

### Color Usage

**Semantic Colors** (leverage system defaults):

- **Accent**: Primary actions and highlights (system blue)
- **Positive**: Value increases (green)
- **Negative**: Value decreases (red)
- **Neutral**: Informational (gray)
- **Carry-forward**: Dimmed or labeled to distinguish from direct values

**Automatic Dark Mode**: Use semantic color names, test all screens in both modes.

### Typography

- **Screen Titles**: `.title` or `.largeTitle`
- **Section Headers**: `.title2` or `.title3`
- **Primary Content**: `.body`
- **Secondary Info**: `.subheadline` or `.caption`
- **Financial Values**: Monospaced digits for alignment

**Formatting**:

- Currency: Use `Decimal` with `.formatted(currency:)` extension
- Percentages: Use `.formattedPercentage()` extension
- Large numbers: K, M, B suffixes in chart axes

### Iconography

**SF Symbols**:

- Add: `plus.circle.fill`
- Edit: `pencil`
- Delete: `trash`
- Import: `square.and.arrow.down`
- Export: `square.and.arrow.up`
- Info: `info.circle`
- Chart: `chart.pie.fill`, `chart.xyaxis.line`

### Spacing and Layout

- 8pt base unit (small: 8pt, medium: 16pt, large: 24pt)
- Cards: Secondary background, 16pt padding, 10-12pt corner radius
- Lists: Full width within safe areas

### Component Patterns

- **Empty States**: Centered icon, brief message, call-to-action button
- **Loading States**: Progress spinner with text
- **Error States**: Error icon, clear message, suggested action
- **Confirmation Dialogs**: For all destructive actions (delete snapshot, delete asset from snapshot, restore from backup)

______________________________________________________________________

## Accessibility Considerations

### Visual Accessibility

- Use semantic colors (WCAG AA contrast)
- Support Dynamic Type
- Provide non-animated alternatives (Reduce Motion)

### Screen Reader (VoiceOver)

- All interactive elements have clear labels
- Logical reading order
- Actionable items clearly identified

### Keyboard Navigation

- Full keyboard navigation on macOS
- Logical tab order
- Visible focus indicators

______________________________________________________________________

# Part 2: Implementation Guide

## SwiftUI Implementation Patterns

### Navigation Structure

```swift
NavigationSplitView {
    // Sidebar
    List(selection: $selectedSection) {
        NavigationLink(value: Section.dashboard) {
            Label("Dashboard", systemImage: "chart.bar")
        }
        NavigationLink(value: Section.snapshots) {
            Label("Snapshots", systemImage: "calendar")
        }
        // ... other items
    }
    .navigationSplitViewColumnWidth(min: 180, ideal: 220)
} detail: {
    switch selectedSection {
    case .dashboard:
        DashboardView()
    case .snapshots:
        SnapshotsSplitView()
    // ... other sections
    }
}
.frame(minWidth: 900, minHeight: 600)
```

### List-Detail Split Pattern

For sections with list-detail (Snapshots, Assets, Categories, Platforms), the outer `NavigationSplitView` provides the sidebar+detail layout, and each inner split view provides the list+detail layout within the detail column. This creates a 3-column layout on macOS (sidebar | list | detail). Use `NavigationSplitView(columnVisibility:)` with `.all` to ensure the 3-column mode is available:

```swift
struct SnapshotsSplitView: View {
    @Query(sort: \Snapshot.date, order: .reverse)
    private var snapshots: [Snapshot]
    @State private var selectedSnapshot: Snapshot?

    var body: some View {
        NavigationSplitView {
            List(snapshots, selection: $selectedSnapshot) { snapshot in
                SnapshotRowView(snapshot: snapshot)
            }
            .toolbar {
                Button("New Snapshot", systemImage: "plus") { /* ... */ }
            }
        } detail: {
            if let snapshot = selectedSnapshot {
                SnapshotDetailView(snapshot: snapshot)
            } else {
                ContentUnavailableView(
                    "Select a Snapshot",
                    systemImage: "calendar",
                    description: Text("Select a snapshot to view details")
                )
            }
        }
    }
}
```

### Chart Implementation

Use Swift Charts framework:

```swift
import Charts

// Pie chart for category allocation
Chart(categoryData) { item in
    SectorMark(
        angle: .value("Value", item.value),
        innerRadius: .ratio(0.5)
    )
    .foregroundStyle(by: .value("Category", item.name))
}

// Line chart for portfolio value
Chart(snapshotData) { point in
    LineMark(
        x: .value("Date", point.date),
        y: .value("Value", point.compositeValue)
    )
    PointMark(
        x: .value("Date", point.date),
        y: .value("Value", point.compositeValue)
    )
}
```

### Import Screen Implementation

```swift
struct ImportView: View {
    @State private var viewModel = ImportViewModel()

    var body: some View {
        VStack {
            // Import type selector
            Picker("Import Type", selection: $viewModel.importType) {
                Text("Assets").tag(ImportType.assets)
                Text("Cash Flows").tag(ImportType.cashFlows)
            }
            .pickerStyle(.segmented)

            // File drop zone
            FileDropZone(url: $viewModel.selectedFile)

            // Configuration (date, platform, category)
            if viewModel.selectedFile != nil {
                ImportConfigurationView(viewModel: viewModel)
                ImportPreviewTable(viewModel: viewModel)
                ImportValidationSummary(viewModel: viewModel)
            }

            // Import button
            Button("Import") { viewModel.executeImport() }
                .disabled(viewModel.isImportDisabled)
        }
    }
}
```

### Reusable Components

**CurrencyText**: Use `Decimal.formatted(currency:)` extension

```swift
Text(value.formatted(currency: settings.displayCurrency))
    .font(.title2)
    .fontWeight(.semibold)
```

**PercentageText**: Color-coded percentage display

```swift
Text(percentage.formattedPercentage())
    .foregroundColor(percentage >= 0 ? .green : .red)
```

**MetricCard**: Card container for dashboard metrics

```swift
VStack(alignment: .leading, spacing: 8) {
    HStack {
        Text("Total Portfolio Value")
            .font(.subheadline)
            .foregroundColor(.secondary)
        Button(action: { showTooltip.toggle() }) {
            Image(systemName: "info.circle")
        }
    }
    Text(value.formatted(currency: "USD"))
        .font(.title)
        .fontWeight(.bold)
}
.padding()
.background(.regularMaterial)
.cornerRadius(10)
```

______________________________________________________________________

## Development Workflow

### Before Building a Screen

1. Define the screen's purpose in one sentence
1. Identify which models/queries are needed
1. Choose container (List, Form, ScrollView, or custom layout)
1. Plan navigation (how users arrive and leave)

### While Building

1. Use Xcode Previews for rapid iteration
1. Test with realistic data and edge cases
1. Check light and dark mode
1. Verify Dynamic Type scaling

### After Implementation

1. Add empty states
1. Add loading states (if async)
1. Add error handling UI
1. Verify keyboard navigation
1. Test VoiceOver (basic navigation)

______________________________________________________________________

## Resources

### Apple Documentation

- [Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SF Symbols App](https://developer.apple.com/sf-symbols/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui/)
- [Swift Charts](https://developer.apple.com/documentation/charts)
- [Accessibility Guidelines](https://developer.apple.com/accessibility/)

### Specification Reference

- `SPEC.md` Sections 3, 4, 12 for detailed UI requirements
