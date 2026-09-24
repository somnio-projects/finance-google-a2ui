"""The curated asset rows, as data (spec 0025 OD-2).

Split from ``market.py`` for the reason ``seed_data.py`` is split from
``seed.py``: a table that never changes at runtime is data, and keeping it
beside the model that parses it pushed that module past the 150-line budget.

Every figure is a **string**, parsed to ``Decimal`` by ``MarketAsset``
(ADR-E D-5).

**The previous closes were solved, not chosen** — spec 0026 §3 records the
six constraints and the two rules (no fund among movers, no non-mover moving
more than the third) that fixed them together.
"""

# ruff: noqa: E501 -- the reference rows are a table a reader compares against
# the design page; wrapping them defeats that, so the line rule yields here.
from typing import Final

from app.domain.taxonomy import AssetClass, Sector

# symbol, name, price, previous close, asset class, sector, is_fund
# (ADR-E D-5 — never a float). The seven rows the design draws in
# `Holdings.dc.html` come first, in its order; the rest close the gap between
# that visible list and the class totals it also states (spec 0025 §2.1, OD-1).
# fmt: off
# symbol, name, price, previous close, asset class, sector, is_fund
# (ADR-E D-5 — never a float). One row per line on purpose: this is a table a
# reader compares against the design page, and a formatter that wraps each
# tuple over eight lines turns it into something nobody can compare.
REFERENCE_ROWS: Final[
    tuple[tuple[str, str, str, str, AssetClass, Sector | None, bool], ...]
] = (
    # Drawn in the design, exactly as drawn, in its order.
    ("NVDA", "NVIDIA Corp", "1204.66", "1156.10", AssetClass.EQUITIES, Sector.TECHNOLOGY, False),
    ("AAPL", "Apple Inc.", "233.18", "230.64", AssetClass.EQUITIES, Sector.TECHNOLOGY, False),
    ("MSFT", "Microsoft Corp", "423.00", "423.22", AssetClass.EQUITIES, Sector.TECHNOLOGY, False),
    ("VOO", "Vanguard S&P 500 ETF", "528.00", "555.00", AssetClass.EQUITIES, Sector.OTHER, True),
    ("BND", "Vanguard Total Bond", "71.40", "71.55", AssetClass.BONDS, None, True),
    ("PYPL", "PayPal Holdings", "65.30", "65.55", AssetClass.EQUITIES, Sector.FINANCIALS, False),
    ("USD", "Cash & sweep", "1.00", "1.00", AssetClass.CASH, None, False),
    # Below the fold of the design's scrollable list (spec 0025 OD-1).
    ("JNJ", "Johnson & Johnson", "155.00", "156.55", AssetClass.EQUITIES, Sector.HEALTHCARE, False),
    ("PG", "Procter & Gamble", "168.00", "169.70", AssetClass.EQUITIES, Sector.CONSUMER, False),
    ("XOM", "Exxon Mobil", "34.22", "34.57", AssetClass.EQUITIES, Sector.ENERGY, False),
    ("AGG", "iShares Core US Aggregate Bond", "97.50", "97.70", AssetClass.BONDS, None, True),
    ("TIP", "iShares TIPS Bond", "121.90", "122.05", AssetClass.BONDS, None, True),
    ("GLD", "SPDR Gold Shares", "198.00", "195.30", AssetClass.ALTERNATIVES, None, True),
    ("VNQ", "Vanguard Real Estate", "90.86", "89.50", AssetClass.ALTERNATIVES, None, True),
    # Tradable but not held: Flow C's order (AVGO, AMD) and Home's movers (TSLA).
    ("AVGO", "Broadcom Inc.", "1740.00", "1722.50", AssetClass.EQUITIES, Sector.TECHNOLOGY, False),
    ("AMD", "Advanced Micro Devices", "166.70", "167.90", AssetClass.EQUITIES, Sector.TECHNOLOGY, False),
    ("TSLA", "Tesla, Inc.", "298.04", "305.06", AssetClass.EQUITIES, Sector.CONSUMER, False),
)
# fmt: on

__all__ = ["REFERENCE_ROWS"]
