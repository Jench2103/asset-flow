# Rebalancing

The Rebalancing tool shows you exactly how your current portfolio allocation compares to your targets and suggests what to buy or sell to get back on track.

!!! note

    AssetFlow's rebalancing tool is a read-only calculator. It shows suggestions — you'll need to execute any trades yourself through your brokerage.

## How It Works

Rebalancing compares your **current allocation** (based on the latest snapshot) against the **target allocations** you've set on your categories. It calculates the difference and tells you how much to buy or sell in each category to reach your targets.

## Reading the Rebalancing Table

At the top, you'll see your **Total Portfolio Value**.

Below that, the table is divided into three sections:

1. **Categories with Targets** — the main rebalancing view, showing categories where you've defined a target allocation.
1. **No Target Set** — categories that exist but don't have a target allocation assigned.
1. **Uncategorized** — assets that haven't been assigned to any category.

Each row in the table includes:

| Column            | Description                                   |
| ----------------- | --------------------------------------------- |
| **Category**      | The category name                             |
| **Current Value** | The total value of assets in this category    |
| **Current %**     | This category's share of your portfolio       |
| **Target %**      | Your desired allocation for this category     |
| **Difference**    | The gap between current and target allocation |
| **Action**        | What you need to do to reach your target      |

Actions are color-coded for quick scanning:

- **Buy** (green) — the amount you need to purchase to reach your target.
- **Sell** (red) — the amount you need to sell to reduce to your target.
- **No Action** (gray) — you're already at your target. Nice work!

![Rebalancing](../../assets/images/rebalancing.png)

## Suggested Moves

At the bottom of the view, you'll find a **Suggested Moves** summary with natural-language descriptions of the key actions needed to bring your portfolio back into balance.

## Prerequisites

To use the rebalancing tool, you'll need:

- At least one snapshot with assets.
- Categories with target allocations set.
- Assets assigned to categories.

!!! tip

    Start by setting target allocations on your categories (e.g., Equities 60%, Bonds 30%, Cash 10%). Then the rebalancing tool will automatically calculate what you need to do.

## See also

- [Categories](categories.md): Create categories and set target allocations
- [Assets](assets.md): Assign assets to categories
- [Dashboard](dashboard.md): See your allocation breakdown at a glance
