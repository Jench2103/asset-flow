# Cash Flows

Cash flows record external money movements — deposits into and withdrawals from your portfolio. Recording these accurately is important because they directly affect how AssetFlow calculates your investment returns.

## What Counts as a Cash Flow?

- **Deposit** — money added to your portfolio from outside. For example, a monthly savings contribution or a bonus you decide to invest.
- **Withdrawal** — money taken out of your portfolio. For example, selling investments to cover an expense.
- **Not a cash flow** — moving money between assets *within* your portfolio (e.g., selling stocks to buy bonds). These internal transfers don't change your portfolio's total external funding.

## Adding Cash Flows

1. Navigate to a snapshot's detail view.
1. Scroll down to the **Cash Flow Operations** section.
1. Click **Add Cash Flow**.
1. Enter a **Description** and an **Amount** — use a positive number for deposits and a negative number for withdrawals.

You can also import cash flows in bulk from a CSV file. See [Import CSV](import-csv.md) for details.

## Editing and Deleting

- **Right-click** any cash flow entry to see the context menu.
- Choose **Edit** to open a popover where you can change the description and amount.
- Choose **Remove** to delete the cash flow.

## How Cash Flows Affect Returns

Without cash flow tracking, a $10,000 deposit would look like your investments grew by $10,000 — even though that money came from your bank account, not from investment gains. AssetFlow uses your cash flow data to separate actual investment performance from external money movements, giving you an accurate picture of how well your investments are really doing.

Head over to [Performance Metrics](performance-metrics.md) for a detailed explanation of how returns are calculated.

!!! tip

    Record all deposits and withdrawals for each snapshot period. The more accurate your cash flow data, the more meaningful your performance metrics will be.

![Snapshot detail with cash flows](../../assets/images/snapshot-detail.png)

## See also

- [Performance Metrics](performance-metrics.md): Understand how cash flows factor into return calculations
- [Snapshots](snapshots.md): Create and manage portfolio snapshots
- [Import CSV](import-csv.md): Bulk-import cash flows from a spreadsheet
