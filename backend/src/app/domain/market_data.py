"""The curated asset rows, as data (spec 0044 OD-1, OD-2).

Split from ``market.py`` for the reason ``seed_data.py`` is split from
``seed.py``: a table that never changes at runtime is data, and keeping it
beside the model that parses it pushed that module past the 150-line budget.

Every figure is a **string**, parsed to ``Decimal`` by ``MarketAsset``
(ADR-E D-5).

**Eight assets, and the universe is the argument (spec 0044 OD-1).** Three
layer 1s, one layer 2, one stablecoin, one DeFi protocol, one oracle network,
and one more layer 1 that the portfolio traded out of. Eight is what gives the
donut five distinct slices, the waterfall both signs and the tax-lot table two
terms; a shorter list makes an empty-looking chart and a longer one makes
every slice a sliver.

**Prices are a static fixture, not a feed (OD-3).** The catalog examples and
the client goldens are re-rendered and diffed by the gate, so a live price
would make the gate fail on a quiet market rather than on a defect.

**The previous closes were solved, not chosen.** The portfolio keeps the
design's total market value and all-time gain (spec 0044 OD-4), and the day's
movers have to read as a list: two down and one up, clearly ordered, with the
settlement asset never in it.
"""

# ruff: noqa: E501 -- the reference rows are a table a reader compares against
# the design page; wrapping them defeats that, so the line rule yields here.
from typing import Final

from app.domain.taxonomy import AssetClass, Sector

# fmt: off
# symbol, name, price, previous close, asset class, ecosystem, stepper step
# (ADR-E D-5 — never a float). One row per line on purpose: this is a table a
# reader compares against the design page, and a formatter that wraps each
# tuple over eight lines turns it into something nobody can compare.
#
# ``step`` is what one tap of the order ticket's stepper moves this leg by
# (spec 0044 OD-6). It is a property of the asset, not of the widget: one unit
# of BTC is four months of the demo portfolio's cash, and one unit of ARB is
# eighty-six cents, so a single step size cannot serve both.
REFERENCE_ROWS: Final[
    tuple[tuple[str, str, str, str, AssetClass, Sector | None, str], ...]
] = (
    # Held, in the order the design's scrollable list draws them: largest
    # first, the settlement asset last.
    ("BTC", "Bitcoin", "64250.00", "61980.00", AssetClass.LAYER1, Sector.BITCOIN, "0.01"),
    ("ETH", "Ethereum", "3480.00", "3442.00", AssetClass.LAYER1, Sector.ETHEREUM, "0.1"),
    ("SOL", "Solana", "152.40", "156.80", AssetClass.LAYER1, Sector.SOLANA, "1"),
    ("LINK", "Chainlink", "22.60", "23.15", AssetClass.INFRASTRUCTURE, Sector.ETHEREUM, "10"),
    ("AAVE", "Aave", "248.00", "259.50", AssetClass.DEFI, Sector.ETHEREUM, "0.1"),
    ("ARB", "Arbitrum", "0.8640", "0.8420", AssetClass.LAYER2, Sector.ETHEREUM, "100"),
    # The settlement asset. No ecosystem on purpose: USDC is natively issued on
    # every chain above, so naming one would be a false denominator (OD-2).
    ("USDC", "USD Coin", "1.00", "1.00", AssetClass.STABLECOIN, None, "100"),
    # Tradable but not held: the round trip the ledger remembers and the
    # holdings list correctly does not carry, and the day's largest mover.
    ("AVAX", "Avalanche", "41.80", "44.60", AssetClass.LAYER1, Sector.AVALANCHE, "1"),
)
# fmt: on

__all__ = ["REFERENCE_ROWS"]
