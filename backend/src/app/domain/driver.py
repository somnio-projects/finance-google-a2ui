"""One driver of the day's move, in detail (GGU-100, Flow A's drill-down).

Tapping a waterfall bar asks *what did this holding do today*: how much it
contributed, how far its price moved, how many units carried that move and
what share of the portfolio's day it was. Every figure is the arithmetic
``app.domain.day_change`` already does over ``price`` and ``previous_close``;
this module composes it for one symbol and ranks it among the rest, so the
projection that draws the card and the tool that narrates it read one result
instead of each computing their own (ADR-K D-5).

Pure and deterministic: the portfolio is the only input, and the market
reference is a constant.
"""

from decimal import Decimal
from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.day_change import (
    change_ratio,
    day_change,
    portfolio_previous_value,
)
from app.domain.holdings import Holding
from app.domain.market import market_asset
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio
from app.domain.symbols import SYMBOL_PATTERN, normalize_symbol

#: Where a driver stands among the day's movers. ``top_contributor`` is the
#: design's *Top contributor today*; the rest are what the same card says for
#: any other bar a reader may tap.
Standing = Literal[
    "top_contributor", "contributor", "top_detractor", "detractor", "unchanged"
]


class DriverDetail(BaseModel):
    """What one holding did today, and where that put it among the others."""

    model_config = ConfigDict(frozen=True)

    symbol: str = Field(pattern=SYMBOL_PATTERN, description="Ticker.")
    name: str = Field(min_length=1, max_length=64, description="Display name.")
    quantity: Decimal = Field(gt=0, description="Units held.")
    price: Decimal = Field(gt=0, description="Today's unit price.")
    price_change: Decimal = Field(description="``price - previous_close``.")
    price_ratio: Decimal = Field(description="Signed day move of the price.")
    contribution: Decimal = Field(description="What the position added today.")
    day_gain: Decimal = Field(description="The whole portfolio's move today.")
    share: Decimal = Field(
        description=(
            "``contribution / day_gain``; zero when the portfolio did not move. "
            "Above one when the rest of the portfolio moved the other way."
        )
    )
    standing: Standing = Field(description="Rank word among the day's movers.")
    rank: int = Field(ge=1, description="1 for the top of its standing.")


def _same_side(holdings: list[Holding], delta: Decimal) -> list[str]:
    """The symbols that moved the way ``delta`` did, largest move first."""
    side = [row for row in holdings if (day_change(row) > ZERO) == (delta > ZERO)]
    side.sort(key=lambda row: (-abs(day_change(row)), row.symbol))
    return [row.symbol for row in side]


def _standing(delta: Decimal, rank: int) -> Standing:
    """The rank word for a move of ``delta`` placed ``rank``-th on its side."""
    if delta > ZERO:
        return "top_contributor" if rank == 1 else "contributor"
    return "top_detractor" if rank == 1 else "detractor"


def _ranked(holdings: list[Holding], held: Holding) -> tuple[Standing, int]:
    """Place ``held`` among the contributors or the detractors."""
    delta = day_change(held)
    if delta == ZERO:
        return "unchanged", 1
    rank = _same_side(holdings, delta).index(held.symbol) + 1
    return _standing(delta, rank), rank


def driver_detail(portfolio: Portfolio, symbol: str) -> DriverDetail | None:
    """Describe what ``symbol`` did to ``portfolio`` today.

    Args:
        portfolio: The domain aggregate, read at its ``as_of``.
        symbol: A ticker in any case.

    Returns:
        The detail, or ``None`` when the portfolio holds no such position —
        the leaf a drill can reach, answered rather than raised so a caller
        decides what to say.
    """
    canonical = normalize_symbol(symbol)
    holdings = portfolio.holdings()
    held = next((row for row in holdings if row.symbol == canonical), None)
    if held is None:
        return None
    asset = market_asset(canonical)
    gain = portfolio.total_market_value() - portfolio_previous_value(holdings)
    contribution = day_change(held)
    standing, rank = _ranked(holdings, held)
    return DriverDetail(
        symbol=held.symbol,
        name=held.name,
        quantity=held.quantity,
        price=held.price,
        price_change=held.price - asset.previous_close,
        price_ratio=change_ratio(held.price, asset.previous_close),
        contribution=contribution,
        day_gain=gain,
        share=contribution / gain if gain != ZERO else ZERO,
        standing=standing,
        rank=rank,
    )


__all__ = ["DriverDetail", "Standing", "driver_detail"]
