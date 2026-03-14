# Categories

Categories let you group your assets by type — such as Equities, Bonds, Real Estate, Cash, or any grouping that makes sense for your portfolio. Each category can have a **target allocation** to help you with rebalancing.

## Category List

The left side of the Categories view shows all your categories. You can **drag to reorder** them — the order you set here is used throughout the app.

Each row displays:

- Category name
- Target allocation %
- Current allocation %
- Current value
- Asset count
- A deviation indicator (**warning icon**) that appears when the current allocation differs from the target by more than 5%

### Banners

Two informational banners may appear at the top of the list:

- **Target Allocation Sum Warning** — shown if your total target allocations exceed 100%, or if some categories are missing targets. This helps you catch configuration issues.
- **Significant Deviation Info** — shown when one or more categories have meaningful deviations from their targets, with a link to the [Rebalancing](rebalancing.md) tool.

Right-click a category to delete it (only available if no assets are assigned to it).

![Category list](../../assets/images/category-list.png)

## Creating a Category

Click the **+** button in the toolbar to create a new category. You'll be asked to enter:

- **Category Name** — a descriptive name for the group (e.g., "Equities", "Fixed Income", "Alternatives").
- **Target Allocation %** — optional, between 0 and 100. This is the percentage of your portfolio you'd like this category to represent.

## Category Detail

Select a category to see its detail view on the right side.

### Properties

- **Name** — editable directly in the detail view.
- **Target Allocation %** — editable, with the same 0–100 range.

### Assets in Category

A table showing all assets assigned to this category, with each asset's name and platform.

### Value History

A line chart showing the category's total value over time. Use the time range selector to focus on a specific period.

### Allocation History

A line chart showing how the category's allocation percentage has changed over time. A **target line** is overlaid for easy comparison, so you can see at a glance how closely your actual allocation has tracked your goal.

![Category detail](../../assets/images/category-detail.png)

## Deleting a Category

Categories can only be deleted when **no assets are assigned to them**. If a category still has assets, you'll need to reassign those assets to other categories first, then come back and delete the empty category.

!!! tip

    Use the [Rebalancing](rebalancing.md) tool to see at a glance which categories are over or under their target allocation. It's the quickest way to decide where to invest next.

## See also

- [Rebalancing](rebalancing.md): Compare current allocations to targets
- [Assets](assets.md): Manage individual investments
- [Dashboard](dashboard.md): See category allocation in the pie chart
