"""Curated market reference — the backend's single source of price (OD-5).

This package owns the reference list: symbol, display name, current price,
**previous close**, **asset class**, **ecosystem**, a stepper step and a
placeholder logo. Every price is declared as a **string** and parsed to
``Decimal`` (ADR-E D-5), so a holding's price and the asset list's price are
the same object, not two roundings of the same idea.

**These are crypto assets, and they were equities (spec 0044, superseding
0025 OD-2).** Spec 0025 replaced a crypto list with a US equities one to match
the design pages it was drawing; GGU-114 turns the showcase's subject back to
crypto, and the design match is kept where it is a *figure* rather than a
ticker — the portfolio still totals what `Holdings.dc.html` states and still
shows its all-time gain (OD-4). Replaced rather than extended: two asset
universes in one demo portfolio would make every allocation figure meaningless.

``previous_close`` is a second *price*, not a derived figure, because the
design draws a day change on every legend row and every position row. Deriving
it would be the client computing, and storing only the delta would make the
figure unreconcilable with the price beside it.

The data is deliberately fake and the logo host is an ``.example`` domain — a
demo catalogue must not read like a live feed.
"""

from collections.abc import Mapping
from decimal import Decimal
from typing import Final

from pydantic import BaseModel, ConfigDict, Field

from app.domain.errors import SymbolNotFoundError
from app.domain.market_data import REFERENCE_ROWS
from app.domain.money import Money
from app.domain.symbols import SYMBOL_PATTERN, normalize_symbol
from app.domain.taxonomy import AssetClass, Sector

_LOGO_TEMPLATE: Final[str] = "https://assets.finance-a2ui.example/logos/{slug}.svg"


class MarketAsset(BaseModel):
    """One asset of the curated reference list."""

    model_config = ConfigDict(frozen=True)

    symbol: str = Field(pattern=SYMBOL_PATTERN, description="Ticker of the asset.")
    name: str = Field(
        min_length=1, max_length=64, description="Display name of the asset."
    )
    price: Money = Field(
        gt=0, description="Current price in USD, parsed from a string."
    )
    previous_close: Money = Field(
        gt=0,
        description="Yesterday's close, the other half of every day change.",
    )
    asset_class: AssetClass = Field(
        description="Which slice of the allocation donut this belongs to."
    )
    sector: Sector | None = Field(
        default=None,
        description="Chain family; a multi-chain stablecoin carries none.",
    )
    step: Money = Field(
        gt=0,
        description=(
            "What one tap of the order ticket's stepper moves a leg of this "
            "asset by (spec 0044 OD-6). A property of the asset: a single "
            "step cannot serve both a $64,000 coin and an 86-cent token, and "
            "the client may not derive one (N-2)."
        ),
    )
    logo_url: str = Field(
        min_length=1, max_length=255, description="Placeholder logo for the client."
    )


MARKET_REFERENCE: Final[tuple[MarketAsset, ...]] = tuple(
    MarketAsset(
        symbol=symbol,
        name=name,
        price=Decimal(price),
        previous_close=Decimal(previous_close),
        asset_class=asset_class,
        sector=sector,
        step=Decimal(step),
        logo_url=_LOGO_TEMPLATE.format(slug=symbol.lower()),
    )
    for symbol, name, price, previous_close, asset_class, sector, step in (
        REFERENCE_ROWS
    )
)

_BY_SYMBOL: Final[Mapping[str, MarketAsset]] = {
    asset.symbol: asset for asset in MARKET_REFERENCE
}


def market_asset(symbol: str) -> MarketAsset:
    """Return the reference entry for ``symbol``.

    Args:
        symbol: A ticker in any case, with or without surrounding whitespace.

    Returns:
        The curated entry for that ticker.

    Raises:
        SymbolNotFoundError: When the ticker is not in the reference list.
    """
    canonical = normalize_symbol(symbol)
    try:
        return _BY_SYMBOL[canonical]
    except KeyError as exc:
        msg = f"symbol {canonical!r} is not in the market reference"
        raise SymbolNotFoundError(msg) from exc


def price_of(symbol: str) -> Decimal:
    """Return the current price of ``symbol``.

    Args:
        symbol: A ticker in any case.

    Returns:
        The reference price as an exact ``Decimal``.
    """
    return market_asset(symbol).price


__all__ = ["MARKET_REFERENCE", "MarketAsset", "market_asset", "price_of"]
