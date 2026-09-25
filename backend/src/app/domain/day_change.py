"""What moved since yesterday — per holding, per portfolio, per name (spec 0026).

The design draws a day change in three places: beside every allocation row,
in the Home hero, and as a *Top movers* list. All three are the same
arithmetic over the same two prices, ``price`` and ``previous_close``, so it
lives here once. A presenter that recomputed it would be a second copy free to
disagree with the first — the drift ADR-K exists to remove.

Every function is pure. The market reference is the only input besides the
holding, and the reference is a constant.
"""

from collections.abc import Sequence
from decimal import Decimal
from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.holdings import Holding
from app.domain.market import MARKET_REFERENCE, MarketAsset, market_asset
from app.domain.money import ZERO
from app.domain.taxonomy import AssetClass

Trend = Literal["up", "down", "flat"]

#: How many names the Home page lists under *Top movers today*.
MOVERS: Final[int] = 3


def previous_value(holding: Holding) -> Decimal:
    """Return what ``holding`` was worth at yesterday's close."""
    return holding.quantity * market_asset(holding.symbol).previous_close


def day_change(holding: Holding) -> Decimal:
    """Return how much ``holding`` moved since yesterday, signed."""
    return holding.market_value - previous_value(holding)


def change_ratio(current: Decimal, previous: Decimal) -> Decimal:
    """Return ``(current - previous) / previous`` as a ratio, ``0`` from nothing.

    Args:
        current: Today's value.
        previous: Yesterday's value; a zero base has no meaningful ratio.

    Returns:
        A signed ratio such as ``Decimal("0.0068")`` for +0.68 %.
    """
    if previous == ZERO:
        return ZERO
    return (current - previous) / previous


def trend_of(delta: Decimal) -> Trend:
    """Name the direction of ``delta`` so a widget colours it without maths."""
    if delta > ZERO:
        return "up"
    if delta < ZERO:
        return "down"
    return "flat"


def portfolio_previous_value(holdings: Sequence[Holding]) -> Decimal:
    """Return what the whole portfolio was worth at yesterday's close."""
    return sum((previous_value(row) for row in holdings), ZERO)


class Mover(BaseModel):
    """One name in the day's movers list — a market fact, not a holding."""

    model_config = ConfigDict(frozen=True)

    symbol: str = Field(description="Ticker.", examples=["BTC"])
    name: str = Field(description="Display name.", examples=["Bitcoin"])
    price: Decimal = Field(gt=0, description="Today's price.")
    ratio: Decimal = Field(description="Signed day change as a ratio.")


def _is_tradable_mover(asset: MarketAsset) -> bool:
    """The settlement asset is never a *mover* on the design's list.

    It was ``not asset.is_fund and ...`` while the reference held pooled
    vehicles (spec 0026 OD-4). A crypto universe of eight single names holds
    none, and a flag that is false in every row is a claim the data does not
    support, so the filter now names its only real subject: a dollar-pegged
    token does not move (spec 0044 OD-2).
    """
    return asset.asset_class is not AssetClass.STABLECOIN


def top_movers(*, limit: int = MOVERS) -> tuple[Mover, ...]:
    """Return the ``limit`` single names that moved most today, largest first.

    Drawn from the whole market reference, not from the portfolio: the design
    lists AVAX, which the portfolio traded out of. Ties break on the ticker so
    the order is stable.

    Args:
        limit: How many rows to return.

    Returns:
        Movers sorted by the size of the move, descending.
    """
    rows = [
        Mover(
            symbol=asset.symbol,
            name=asset.name,
            price=asset.price,
            ratio=change_ratio(asset.price, asset.previous_close),
        )
        for asset in MARKET_REFERENCE
        if _is_tradable_mover(asset)
    ]
    rows.sort(key=lambda row: (-abs(row.ratio), row.symbol))
    return tuple(rows[:limit])


__all__ = [
    "MOVERS",
    "Mover",
    "Trend",
    "change_ratio",
    "day_change",
    "portfolio_previous_value",
    "previous_value",
    "top_movers",
    "trend_of",
]
