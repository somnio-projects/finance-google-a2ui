"""Curated market reference — the backend's single source of price (OD-5).

The old sample's ``crypto_data.json`` was deleted with ``backend_python/``, so
this package owns the reference list instead: symbol, display name, current
price and a placeholder logo. Every price is declared as a **string** and
parsed to ``Decimal`` (ADR-E D-5), so a holding's price and the asset list's
price are the same object, not two roundings of the same idea.

The data is deliberately fake and the logo host is an ``.example`` domain — a
demo catalogue must not read like a live feed.
"""

from collections.abc import Mapping
from decimal import Decimal
from typing import Final

from pydantic import BaseModel, ConfigDict, Field

from app.domain.errors import SymbolNotFoundError
from app.domain.money import Money
from app.domain.symbols import SYMBOL_PATTERN, normalize_symbol

_LOGO_TEMPLATE: Final[str] = "https://assets.finance-a2ui.example/logos/{slug}.svg"

# symbol, display name, current price as a string (ADR-E D-5 — never a float).
_REFERENCE_ROWS: Final[tuple[tuple[str, str, str], ...]] = (
    ("BTC", "Bitcoin", "64250.00"),
    ("ETH", "Ethereum", "3180.50"),
    ("SOL", "Solana", "152.40"),
    ("LINK", "Chainlink", "11.85"),
    ("DOGE", "Dogecoin", "0.1273"),
    ("ADA", "Cardano", "0.4825"),
    ("AVAX", "Avalanche", "27.60"),
    ("DOT", "Polkadot", "4.2150"),
)


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
    logo_url: str = Field(
        min_length=1, max_length=255, description="Placeholder logo for the client."
    )


MARKET_REFERENCE: Final[tuple[MarketAsset, ...]] = tuple(
    MarketAsset(
        symbol=symbol,
        name=name,
        price=Decimal(price),
        logo_url=_LOGO_TEMPLATE.format(slug=symbol.lower()),
    )
    for symbol, name, price in _REFERENCE_ROWS
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
