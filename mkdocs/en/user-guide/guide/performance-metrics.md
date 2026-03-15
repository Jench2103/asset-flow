# Performance Metrics

AssetFlow calculates several performance metrics to help you understand how your investments are doing. If you've ever wondered what all those numbers on the Dashboard mean, this page breaks each one down in plain language.

## Growth Rate

**What it is:** The simple percentage change in your portfolio's total value between two dates.

**How it works:** Take the difference between your ending value and starting value, divide by the starting value, and multiply by 100%. That's your growth rate.

**Important:** Growth rate includes the effect of deposits and withdrawals. If you deposited $10,000 during the period, your portfolio will show growth from that deposit even if your investments stayed completely flat.

**Best for:** A quick overview of how your total wealth changed — useful when you want to see the big picture, including the money you added or removed.

## Return Rate (Modified Dietz)

**What it is:** A cash-flow-adjusted return that isolates your investment performance from the effect of deposits and withdrawals.

**How it works:** The Modified Dietz method accounts for *when* money was added or removed during the period, weighting each cash flow by how long it was actually invested. Money deposited at the start of the month counts more than money deposited at the end.

**Why it matters:** If you deposit $10,000 mid-month, the Modified Dietz method won't count that deposit as "growth." It only measures how well your existing money (and newly added money, from the time it was added) actually performed.

**Best for:** Understanding your actual investment performance over a single period. This is the number to look at when you want to know "how did my investments do this month?" without being misled by deposits or withdrawals.

## Cumulative Time-Weighted Return (TWR)

**What it is:** Chains together the returns from each snapshot period to show your total investment performance over time, completely eliminating the impact of cash flow timing.

**How it works:** AssetFlow calculates the return between each consecutive pair of snapshots (using the Modified Dietz method), then compounds them together — like multiplying each period's growth factor. The result shows your overall investment performance as if cash flows never happened.

**Why it matters:** Even if you made a large deposit right before a market dip, the TWR measures how your *investment choices* performed — not your deposit timing. Two people with identical investments but different deposit schedules will see the same TWR.

**Best for:** Long-term performance tracking. This is the industry-standard way to evaluate investment performance, and it's the number fund managers and financial advisors use.

## CAGR (Compound Annual Growth Rate)

**What it is:** The annualized version of your cumulative TWR — it tells you what your portfolio would have grown at per year if growth were perfectly smooth and steady.

**Best for:** Comparing your portfolio's performance to benchmarks. When someone says "the S&P 500 returned 10% per year," that's a CAGR — and now you can compare your own portfolio on the same terms.

---

!!! tip

    If you only look at one number, make it the **Cumulative TWR** — it's the fairest measure of how well your investments are actually performing.

!!! note

    For all these metrics to be accurate, make sure to record your cash flows (deposits and withdrawals) in each snapshot. Without cash flow data, AssetFlow can't distinguish between investment gains and money you added.

## See also

- [Dashboard](dashboard.md): See these metrics in action
- [Cash Flows](cash-flows.md): Learn how to record deposits and withdrawals
