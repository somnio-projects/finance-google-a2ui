"""Curated market reference — the backend's single source of price (OD-5).

This package owns the reference list: symbol, display name, current price,
**previous close**, **asset class**, **sector** and a placeholder logo. Every
price is declared as a **string** and parsed to ``Decimal`` (ADR-E D-5), so a
holding's price and the asset list's price are the same object, not two
roundings of the same idea.

**These are equities, and they used to be crypto (spec 0025 OD-2).** The design
is a US equities portfolio; this backend held eight crypto assets, so no
component could be made to match by styling — the numbers on screen come from
here and were different numbers. Replaced rather than extended: two asset
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
        description="Economic sector; only equities carry one.",
    )
    is_fund: bool = Field(
        default=False,
        description=(
            "A pooled vehicle (ETF, bond fund) rather than a single name. The "
            "Home page's *Top movers* lists single names only, so this is what "
            "keeps a fund out of it (spec 0026 OD-4)."
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
        is_fund=is_fund,
        logo_url=_LOGO_TEMPLATE.format(slug=symbol.lower()),
    )
    for symbol, name, price, previous_close, asset_class, sector, is_fund in (
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
