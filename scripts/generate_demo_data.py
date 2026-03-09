#!/usr/bin/env python3
"""Generate demo data backup ZIP and sample import CSVs for AssetFlow.

Creates:
  1. output/DemoData.zip — v3 backup archive with 13 weeks of portfolio data
  2. output/import_new_snapshot.csv — asset CSV for importing a brand-new snapshot
  3. output/import_assets_to_existing.csv — asset CSV for adding assets to an existing snapshot
  4. output/import_cash_flows.csv — cash flow CSV for adding to an existing snapshot

Snapshot dates are computed relative to today.
"""

from __future__ import annotations

import json
import os
import random
import subprocess
import tempfile
import uuid
from datetime import date, datetime, timedelta, timezone
from decimal import ROUND_HALF_UP, Decimal
from typing import Any

SEED = 42
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
OUTPUT_DIR = os.path.join(SCRIPT_DIR, "output")
ZIP_PATH = os.path.join(OUTPUT_DIR, "DemoData.zip")

NUM_SNAPSHOTS = 13

# Mean and std deviation for the random weekly return used in import CSV generation.
IMPORT_RETURN_MEAN = 0.005
IMPORT_RETURN_STD = 0.008

# Type aliases for readability.
CategoryDict = dict[str, str]
AssetDict = dict[str, str]
SnapshotDict = dict[str, str]
CashFlowDict = dict[str, str]
AssetSpecDict = dict[str, Any]
MarketValueRow = tuple[str, str, str]


# ---------------------------------------------------------------------------
# Data definitions
# ---------------------------------------------------------------------------


def make_uuid() -> str:
    return str(uuid.uuid4()).upper()


def compute_snapshot_dates(today: date) -> list[date]:
    """Return NUM_SNAPSHOTS weekly dates ending on today.

    Weeks go backwards from today, so the last snapshot is always today.
    """
    return [today - timedelta(weeks=i) for i in range(NUM_SNAPSHOTS - 1, -1, -1)]


def define_categories() -> list[CategoryDict]:
    """Return list of category dicts with pre-generated UUIDs."""
    return [
        {"id": make_uuid(), "name": "US Stocks", "target": "35", "order": "0"},
        {
            "id": make_uuid(),
            "name": "International Stocks",
            "target": "20",
            "order": "1",
        },
        {"id": make_uuid(), "name": "Bonds", "target": "15", "order": "2"},
        {"id": make_uuid(), "name": "Crypto", "target": "15", "order": "3"},
        {"id": make_uuid(), "name": "Cash & Equivalents", "target": "10", "order": "4"},
        {"id": make_uuid(), "name": "Real Estate", "target": "5", "order": "5"},
    ]


def define_assets(categories: list[CategoryDict]) -> list[AssetDict]:
    """Return list of asset dicts referencing category IDs."""
    cat: dict[str, str] = {c["name"]: c["id"] for c in categories}
    return [
        # US Stocks
        {
            "id": make_uuid(),
            "name": "S&P 500 ETF (VOO)",
            "platform": "Vanguard",
            "categoryID": cat["US Stocks"],
            "currency": "USD",
        },
        {
            "id": make_uuid(),
            "name": "Apple (AAPL)",
            "platform": "Interactive Brokers",
            "categoryID": cat["US Stocks"],
            "currency": "USD",
        },
        {
            "id": make_uuid(),
            "name": "NVIDIA (NVDA)",
            "platform": "Interactive Brokers",
            "categoryID": cat["US Stocks"],
            "currency": "USD",
        },
        # International Stocks
        {
            "id": make_uuid(),
            "name": "FTSE Europe ETF (VGK)",
            "platform": "Vanguard",
            "categoryID": cat["International Stocks"],
            "currency": "EUR",
        },
        {
            "id": make_uuid(),
            "name": "MSCI Japan ETF (EWJ)",
            "platform": "Interactive Brokers",
            "categoryID": cat["International Stocks"],
            "currency": "USD",
        },
        # Bonds
        {
            "id": make_uuid(),
            "name": "Total Bond ETF (BND)",
            "platform": "Vanguard",
            "categoryID": cat["Bonds"],
            "currency": "USD",
        },
        {
            "id": make_uuid(),
            "name": "TIPS Bond ETF (TIP)",
            "platform": "Schwab",
            "categoryID": cat["Bonds"],
            "currency": "USD",
        },
        # Crypto
        {
            "id": make_uuid(),
            "name": "Bitcoin",
            "platform": "Coinbase",
            "categoryID": cat["Crypto"],
            "currency": "BTC",
        },
        {
            "id": make_uuid(),
            "name": "Ethereum",
            "platform": "Coinbase",
            "categoryID": cat["Crypto"],
            "currency": "ETH",
        },
        # Cash & Equivalents
        {
            "id": make_uuid(),
            "name": "USD Savings Account",
            "platform": "Marcus",
            "categoryID": cat["Cash & Equivalents"],
            "currency": "USD",
        },
        {
            "id": make_uuid(),
            "name": "EUR Money Market",
            "platform": "Wise",
            "categoryID": cat["Cash & Equivalents"],
            "currency": "EUR",
        },
        # Real Estate
        {
            "id": make_uuid(),
            "name": "Real Estate ETF (VNQ)",
            "platform": "Vanguard",
            "categoryID": cat["Real Estate"],
            "currency": "USD",
        },
        {
            "id": make_uuid(),
            "name": "Realty Income (O)",
            "platform": "Schwab",
            "categoryID": cat["Real Estate"],
            "currency": "USD",
        },
    ]


def define_snapshots(snapshot_dates: list[date]) -> list[SnapshotDict]:
    """Return snapshot dicts for the given dates."""
    snapshots: list[SnapshotDict] = []
    for d in snapshot_dates:
        dt = datetime(d.year, d.month, d.day, tzinfo=timezone.utc)
        created = dt.replace(hour=9)
        snapshots.append(
            {
                "id": make_uuid(),
                "date": iso8601(dt),
                "createdAt": iso8601(created),
            }
        )
    return snapshots


# ---------------------------------------------------------------------------
# Market value generation
# ---------------------------------------------------------------------------


def q2(value: Decimal) -> Decimal:
    """Quantize Decimal to 2 decimal places."""
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def q8(value: Decimal) -> Decimal:
    """Quantize Decimal to 8 decimal places (for BTC/ETH)."""
    return value.quantize(Decimal("0.00000001"), rounding=ROUND_HALF_UP)


def gen_values(
    base: int | str,
    weekly_returns: list[float],
    rng: random.Random,
    volatility: Decimal = Decimal("0.005"),
    precision: int = 2,
) -> list[Decimal]:
    """Generate values by applying weekly returns with small random noise."""
    quantize = q2 if precision == 2 else q8
    values: list[Decimal] = []
    current = Decimal(str(base))
    for ret in weekly_returns:
        noise = Decimal(str(round(rng.gauss(0, float(volatility)), 6)))
        current = current * (1 + Decimal(str(ret)) + noise)
        values.append(quantize(current))
    return values


# Asset specifications: base values and weekly return patterns.
ASSET_SPECS: dict[str, AssetSpecDict] = {
    # US Stocks — steady growth with some variation
    "S&P 500 ETF (VOO)": {
        "base": 45000,
        "returns": [
            0.0,
            0.008,
            0.005,
            -0.003,
            0.010,
            0.006,
            -0.004,
            0.012,
            0.007,
            0.005,
            -0.002,
            0.008,
            0.004,
        ],
        "start_week": 0,
    },
    "Apple (AAPL)": {
        "base": 12000,
        "returns": [
            0.0,
            0.005,
            -0.010,
            -0.015,
            -0.008,
            0.012,
            0.015,
            0.010,
            0.008,
            0.005,
            0.003,
            0.007,
            0.006,
        ],
        "start_week": 0,
    },
    "NVIDIA (NVDA)": {
        "base": 8000,
        "returns": [0.0, 0.020, 0.015, -0.010, 0.025, 0.018, -0.008, 0.022, 0.012],
        "start_week": 4,  # Appears at week 4
    },
    # International Stocks — EUR-denominated, moderate
    "FTSE Europe ETF (VGK)": {
        "base": 15000,  # EUR
        "returns": [
            0.0,
            0.004,
            0.003,
            -0.002,
            0.005,
            0.003,
            -0.001,
            0.006,
            0.004,
            0.002,
            -0.003,
            0.005,
            0.003,
        ],
        "start_week": 0,
    },
    "MSCI Japan ETF (EWJ)": {
        "base": 8000,
        "returns": [
            0.0,
            -0.003,
            0.002,
            -0.005,
            -0.002,
            0.001,
            -0.004,
            0.003,
            -0.002,
            -0.003,
            0.001,
            -0.002,
            0.002,
        ],
        "start_week": 0,
    },
    # Bonds — very stable
    "Total Bond ETF (BND)": {
        "base": 20000,
        "returns": [
            0.0,
            0.001,
            0.001,
            0.0,
            0.001,
            0.001,
            0.0,
            0.001,
            0.001,
            0.0,
            0.001,
            0.001,
            0.0,
        ],
        "start_week": 0,
        "volatility": Decimal("0.001"),
    },
    "TIPS Bond ETF (TIP)": {
        "base": 10000,
        "returns": [
            0.0,
            0.001,
            0.0,
            0.001,
            0.001,
            0.0,
            0.001,
            0.001,
            0.0,
            0.001,
            0.001,
            0.0,
            0.001,
        ],
        "start_week": 0,
        "volatility": Decimal("0.001"),
    },
    # Crypto — quantity stays constant
    "Bitcoin": {
        "base": "0.50000000",  # 0.5 BTC
        "returns": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        "start_week": 0,
        "precision": 8,
        "volatility": Decimal("0.0"),
    },
    "Ethereum": {
        "base": "3.50000000",  # 3.5 ETH
        "returns": [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0],
        "start_week": 4,  # Appears at week 4
        "precision": 8,
        "volatility": Decimal("0.0"),
    },
    # Cash & Equivalents — very stable
    "USD Savings Account": {
        "base": 25000,
        "returns": [
            0.0,
            0.0008,
            0.0008,
            0.0008,
            0.0008,
            0.0008,
            0.0008,
            0.0008,
            0.0008,
            0.0008,
            0.0008,
            0.0008,
            0.0008,
        ],
        "start_week": 0,
        "volatility": Decimal("0.0"),
    },
    "EUR Money Market": {
        "base": 8000,  # EUR
        "returns": [
            0.0,
            0.0006,
            0.0006,
            0.0006,
            0.0006,
            0.0006,
            0.0006,
            0.0006,
            0.0006,
            0.0006,
            0.0006,
            0.0006,
            0.0006,
        ],
        "start_week": 0,
        "volatility": Decimal("0.0"),
    },
    # Real Estate — slight decline then recovery
    "Real Estate ETF (VNQ)": {
        "base": 6000,
        "returns": [
            0.0,
            -0.003,
            -0.005,
            -0.002,
            0.001,
            -0.004,
            0.002,
            0.003,
            -0.001,
            0.002,
            -0.003,
            0.004,
            0.002,
        ],
        "start_week": 0,
    },
    "Realty Income (O)": {
        "base": 4000,
        "returns": [
            0.0,
            0.002,
            -0.001,
            0.001,
            0.002,
            -0.002,
            0.003,
            0.001,
            0.002,
            -0.001,
            0.002,
            0.001,
            0.002,
        ],
        "start_week": 0,
    },
}


def generate_market_values(
    assets: list[AssetDict],
    snapshots: list[SnapshotDict],
    rng: random.Random,
) -> tuple[list[MarketValueRow], dict[str, Decimal]]:
    """Generate SnapshotAssetValue rows.

    Returns list of (snapshotID, assetID, marketValue_str) tuples,
    plus a dict mapping (asset_name -> final Decimal value) for reuse.
    """
    asset_by_name: dict[str, AssetDict] = {a["name"]: a for a in assets}
    num_weeks = len(snapshots)

    asset_names = set(asset_by_name.keys())
    spec_names = set(ASSET_SPECS.keys())
    if asset_names != spec_names:
        missing_in_specs = asset_names - spec_names
        missing_in_assets = spec_names - asset_names
        raise ValueError(
            f"ASSET_SPECS / define_assets() mismatch: "
            f"missing in specs={missing_in_specs}, missing in assets={missing_in_assets}"
        )

    rows: list[MarketValueRow] = []
    last_values: dict[str, Decimal] = {}
    for name, spec in ASSET_SPECS.items():
        asset = asset_by_name[name]
        start_week: int = spec["start_week"]
        precision: int = spec.get("precision", 2)
        vol: Decimal = spec.get("volatility", Decimal("0.005"))
        returns: list[float] = spec["returns"]
        base: int | str = spec["base"]

        values = gen_values(base, returns, rng, volatility=vol, precision=precision)
        for i, val in enumerate(values):
            week_idx = start_week + i
            if week_idx < num_weeks:
                rows.append(
                    (
                        snapshots[week_idx]["id"],
                        asset["id"],
                        str(val),
                    )
                )
                last_values[name] = val

    return rows, last_values


def define_cash_flows(snapshots: list[SnapshotDict]) -> list[CashFlowDict]:
    """Return list of cash flow operation dicts."""
    return [
        {
            "id": make_uuid(),
            "snapshotID": snapshots[0]["id"],
            "description": "Initial deposit",
            "amount": "150000",
            "currency": "USD",
        },
        {
            "id": make_uuid(),
            "snapshotID": snapshots[2]["id"],
            "description": "Year-end bonus deposit",
            "amount": "10000",
            "currency": "USD",
        },
        {
            "id": make_uuid(),
            "snapshotID": snapshots[4]["id"],
            "description": "NVDA purchase deposit",
            "amount": "8000",
            "currency": "USD",
        },
        {
            "id": make_uuid(),
            "snapshotID": snapshots[4]["id"],
            "description": "Ethereum purchase deposit",
            "amount": "5000",
            "currency": "USD",
        },
        {
            "id": make_uuid(),
            "snapshotID": snapshots[6]["id"],
            "description": "Monthly savings deposit",
            "amount": "3000",
            "currency": "USD",
        },
        {
            "id": make_uuid(),
            "snapshotID": snapshots[8]["id"],
            "description": "EUR transfer in",
            "amount": "2000",
            "currency": "EUR",
        },
        {
            "id": make_uuid(),
            "snapshotID": snapshots[9]["id"],
            "description": "Withdrawal for expenses",
            "amount": "-5000",
            "currency": "USD",
        },
        {
            "id": make_uuid(),
            "snapshotID": snapshots[11]["id"],
            "description": "Monthly savings deposit",
            "amount": "3000",
            "currency": "USD",
        },
    ]


# ---------------------------------------------------------------------------
# CSV helpers
# ---------------------------------------------------------------------------


def csv_escape(value: str) -> str:
    """Escape a CSV field matching BackupService+Export.swift's csvEscape()."""
    if any(c in value for c in (",", '"', "\n", "\r")):
        return '"' + value.replace('"', '""') + '"'
    return value


def csv_line(fields: list[str]) -> str:
    return ",".join(fields)


def iso8601(dt: datetime) -> str:
    """Format datetime as ISO8601 string matching Swift's ISO8601DateFormatter."""
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


# ---------------------------------------------------------------------------
# Backup ZIP file writers
# ---------------------------------------------------------------------------


def write_manifest(tmpdir: str, today: date) -> None:
    manifest = {
        "formatVersion": 3,
        "exportTimestamp": iso8601(
            datetime(today.year, today.month, today.day, tzinfo=timezone.utc)
        ),
        "appVersion": "1.0",
    }
    path = os.path.join(tmpdir, "manifest.json")
    with open(path, "w") as f:
        json.dump(manifest, f)


def write_categories_csv(tmpdir: str, categories: list[CategoryDict]) -> None:
    lines = ["id,name,targetAllocationPercentage,displayOrder"]
    for c in categories:
        lines.append(
            csv_line(
                [
                    c["id"],
                    csv_escape(c["name"]),
                    c["target"],
                    c["order"],
                ]
            )
        )
    path = os.path.join(tmpdir, "categories.csv")
    with open(path, "w") as f:
        f.write("\n".join(lines))


def write_assets_csv(tmpdir: str, assets: list[AssetDict]) -> None:
    lines = ["id,name,platform,categoryID,currency"]
    for a in assets:
        lines.append(
            csv_line(
                [
                    a["id"],
                    csv_escape(a["name"]),
                    csv_escape(a["platform"]),
                    a["categoryID"],
                    csv_escape(a["currency"]),
                ]
            )
        )
    path = os.path.join(tmpdir, "assets.csv")
    with open(path, "w") as f:
        f.write("\n".join(lines))


def write_snapshots_csv(tmpdir: str, snapshots: list[SnapshotDict]) -> None:
    lines = ["id,date,createdAt"]
    for s in snapshots:
        lines.append(csv_line([s["id"], s["date"], s["createdAt"]]))
    path = os.path.join(tmpdir, "snapshots.csv")
    with open(path, "w") as f:
        f.write("\n".join(lines))


def write_snapshot_asset_values_csv(tmpdir: str, values: list[MarketValueRow]) -> None:
    lines = ["snapshotID,assetID,marketValue"]
    for snapshot_id, asset_id, market_value in values:
        lines.append(csv_line([snapshot_id, asset_id, market_value]))
    path = os.path.join(tmpdir, "snapshot_asset_values.csv")
    with open(path, "w") as f:
        f.write("\n".join(lines))


def write_cash_flow_operations_csv(tmpdir: str, cash_flows: list[CashFlowDict]) -> None:
    lines = ["id,snapshotID,description,amount,currency"]
    for cf in cash_flows:
        lines.append(
            csv_line(
                [
                    cf["id"],
                    cf["snapshotID"],
                    csv_escape(cf["description"]),
                    cf["amount"],
                    csv_escape(cf["currency"]),
                ]
            )
        )
    path = os.path.join(tmpdir, "cash_flow_operations.csv")
    with open(path, "w") as f:
        f.write("\n".join(lines))


def write_settings_csv(tmpdir: str) -> None:
    lines = [
        "key,value",
        "displayCurrency,USD",
        "dateFormat,abbreviated",
        "defaultPlatform,",
    ]
    path = os.path.join(tmpdir, "settings.csv")
    with open(path, "w") as f:
        f.write("\n".join(lines))


def create_zip(tmpdir: str, output_path: str) -> None:
    """Create ZIP using ditto to match BackupService."""
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    if os.path.exists(output_path):
        os.remove(output_path)
    subprocess.run(
        ["/usr/bin/ditto", "-c", "-k", "--sequesterRsrc", tmpdir, output_path],
        check=True,
    )


# ---------------------------------------------------------------------------
# Import CSV generators
# ---------------------------------------------------------------------------


def write_import_new_snapshot_csv(
    output_dir: str,
    assets: list[AssetDict],
    last_values: dict[str, Decimal],
    rng: random.Random,
) -> None:
    """Generate an asset import CSV for a brand-new snapshot.

    Contains all 13 assets with slightly evolved values from the last snapshot,
    to be imported on a future date not yet in the backup data.
    """
    asset_by_name: dict[str, AssetDict] = {a["name"]: a for a in assets}
    lines = ["Asset Name,Market Value,Platform,Currency"]
    for name, spec in ASSET_SPECS.items():
        precision: int = spec.get("precision", 2)
        quantize = q2 if precision == 2 else q8
        vol: Decimal = spec.get("volatility", Decimal("0.005"))

        if name in last_values:
            # Apply one more week of return + noise
            ret = Decimal(
                str(round(rng.gauss(IMPORT_RETURN_MEAN, IMPORT_RETURN_STD), 6))
            )
            if vol == Decimal("0"):
                new_val = last_values[name]
            else:
                new_val = quantize(last_values[name] * (1 + ret))
        else:
            new_val = quantize(Decimal(str(spec["base"])))

        asset = asset_by_name[name]
        lines.append(
            csv_line(
                [
                    csv_escape(name),
                    str(new_val),
                    csv_escape(asset["platform"]),
                    csv_escape(asset["currency"]),
                ]
            )
        )

    path = os.path.join(output_dir, "import_new_snapshot.csv")
    with open(path, "w") as f:
        f.write("\n".join(lines))
    print(f"Import CSV (new snapshot) written to {path}")


def write_import_assets_to_existing_csv(output_dir: str) -> None:
    """Generate an asset import CSV for adding new assets to an existing snapshot.

    Contains 3 new assets NOT already in the backup data, suitable for importing
    into an existing snapshot date.
    """
    lines = ["Asset Name,Market Value,Platform,Currency"]
    new_assets: list[tuple[str, str, str, str]] = [
        ("Tesla (TSLA)", "7500.00", "Interactive Brokers", "USD"),
        ("Gold ETF (GLD)", "5000.00", "Vanguard", "USD"),
        ("Solana", "1.25000000", "Coinbase", "SOL"),
    ]
    for name, value, platform, currency in new_assets:
        lines.append(
            csv_line(
                [
                    csv_escape(name),
                    value,
                    csv_escape(platform),
                    currency,
                ]
            )
        )

    path = os.path.join(output_dir, "import_assets_to_existing.csv")
    with open(path, "w") as f:
        f.write("\n".join(lines))
    print(f"Import CSV (assets to existing) written to {path}")


def write_import_cash_flows_csv(output_dir: str) -> None:
    """Generate a cash flow import CSV for adding to an existing snapshot.

    Contains 3 cash flow operations with mixed currencies and directions.
    """
    lines = ["Description,Amount,Currency"]
    cash_flows: list[tuple[str, str, str]] = [
        ("Quarterly dividend", "850.00", "USD"),
        ("Wire transfer from Europe", "1500.00", "EUR"),
        ("Insurance premium payment", "-320.00", "USD"),
    ]
    for desc, amount, currency in cash_flows:
        lines.append(
            csv_line(
                [
                    csv_escape(desc),
                    amount,
                    currency,
                ]
            )
        )

    path = os.path.join(output_dir, "import_cash_flows.csv")
    with open(path, "w") as f:
        f.write("\n".join(lines))
    print(f"Import CSV (cash flows) written to {path}")


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------


def main() -> None:
    rng = random.Random(SEED)
    today = date.today()

    # Compute snapshot dates relative to today
    snapshot_dates = compute_snapshot_dates(today)

    categories = define_categories()
    assets = define_assets(categories)
    snapshots = define_snapshots(snapshot_dates)
    market_values, last_values = generate_market_values(assets, snapshots, rng)
    cash_flows = define_cash_flows(snapshots)

    # 1. Generate backup ZIP
    with tempfile.TemporaryDirectory() as tmpdir:
        write_manifest(tmpdir, today)
        write_categories_csv(tmpdir, categories)
        write_assets_csv(tmpdir, assets)
        write_snapshots_csv(tmpdir, snapshots)
        write_snapshot_asset_values_csv(tmpdir, market_values)
        write_cash_flow_operations_csv(tmpdir, cash_flows)
        write_settings_csv(tmpdir)
        create_zip(tmpdir, ZIP_PATH)

    print(f"Backup ZIP written to {ZIP_PATH}")
    print(f"  Snapshots span {snapshot_dates[0]} to {snapshot_dates[-1]}")

    # 2. Generate sample import CSVs
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    write_import_new_snapshot_csv(OUTPUT_DIR, assets, last_values, rng)
    write_import_assets_to_existing_csv(OUTPUT_DIR)
    write_import_cash_flows_csv(OUTPUT_DIR)


if __name__ == "__main__":
    main()
