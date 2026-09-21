"""What the whole portfolio was worth on each of the last N days (spec 0026 OD-3).

The Home page draws a sparkline of the portfolio's value and a range selector
whose delta is measured against a point in that history. Both need one series,
so it is built here once: for each day, the sum over holdings of quantity
times that day's generated price.

Cash does not drift. ``price_on`` generates a deterministic wobble for every
symbol, and a dollar that was worth 91 cents last Tuesday is not a simulation,
it is a bug — so the cash balance is carried flat.

The series is a function of the seed and ``as_of`` alone, so two reads of the
same range agree (OD-5 of spec 0025 said so before anything drew it).
"""

from collections.abc import Sequence
from datetime import date, timedelta
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.history import HISTORY_DAYS, price_on
from app.domain.holdings import Holding
from app.domain.market import market_asset
from app.domain.money import ZERO
from app.domain.taxonomy import AssetClass


class ValuePoint(BaseModel):
    """The portfolio's value on one day."""

    model_config = ConfigDict(frozen=True)

    observed_on: date = Field(description="The day this value belongs to (UTC).")
    value: Decimal = Field(ge=0, description="Sum of every holding's value that day.")


def value_on(holdings: Sequence[Holding], *, offset: int) -> Decimal:
    """Return what ``holdings`` were worth ``offset`` days before ``as_of``.

    Args:
        holdings: The positions, quantities as held today.
        offset: Days back; ``0`` is today and reproduces the market value.

    Returns:
        The summed value, exact.
    """
    total = ZERO
    for row in holdings:
        asset = market_asset(row.symbol)
        price = (
            asset.price
            if asset.asset_class is AssetClass.CASH
            else (price_on(row.symbol, offset=offset))
        )
        total += row.quantity * price
    return total


def value_series(
    holdings: Sequence[Holding], *, as_of: date, points: int
) -> tuple[ValuePoint, ...]:
    """Return ``points`` daily values ending at ``as_of``, oldest first.

    Args:
        holdings: The positions.
        as_of: The day the series ends on.
        points: How many days; clamped to the generated history's depth.

    Returns:
        The series, ascending by date; empty when ``points`` is not positive.
    """
    count = max(0, min(points, HISTORY_DAYS))
    return tuple(
        ValuePoint(
            observed_on=as_of - timedelta(days=offset),
            value=value_on(holdings, offset=offset),
        )
        for offset in reversed(range(count))
    )


__all__ = ["ValuePoint", "value_on", "value_series"]
