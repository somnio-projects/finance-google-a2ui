"""Display shaping for ``payoff`` (spec 0014 §3).

`payoff_limits` holds the bounds, `payoff_order` decides what was asked, and
`payoff` is the tool. Every function here is pure and returns nothing but
strings and the trend token, so "did a raw number escape into the payload?" is
a question about this file alone.

It registers no tool: ``load_tools()`` imports it and nothing happens, which is
the cost of keeping a tool's helper beside the tool instead of in a shared file
(spec 0006 AC-7).
"""

from collections.abc import Mapping
from decimal import Decimal
from typing import Final

from app.core.display import (
    MONEY_PRECISION,
    QUANTITY_PRECISION,
    money_display,
    percentage_display,
    quantity_display,
)
from app.core.signed_display import (
    signed_money_display,
)
from app.core.trend import trend_of
from app.domain.payoff import PayoffCurve, PayoffPoint

#: A payoff ladder is the one surface where two decimals is not merely coarse
#: but self-contradictory: on a sub-dollar ticker, adjacent grid prices render
#: identical while the profit beside them differs, and one payload then says
#: both "at $0.13 you make $6.36" and "at $0.13 you lose $0.25"
#: (spec 0014 OD-10). The precision therefore comes from the curve's own step
#: and is fed to ``money_display``'s existing ``precision`` argument — the same
#: formatter, asked for the resolution this particular grid needs.
MAX_PRICE_PRECISION: Final[int] = QUANTITY_PRECISION


def price_precision(step: Decimal) -> int:
    """Return the decimal places two adjacent grid prices need to differ.

    Args:
        step: The distance between two neighbouring prices on the curve.

    Returns:
        The smallest precision from ``MONEY_PRECISION`` up that can still tell
        the two apart, capped at ``MAX_PRICE_PRECISION`` — a grid finer than
        eight decimals is beyond what any price in this domain can express.
    """
    for places in range(MONEY_PRECISION, MAX_PRICE_PRECISION):
        if step >= Decimal(1).scaleb(-places):
            return places
    return MAX_PRICE_PRECISION


def _percentage_or_none(ratio: Decimal | None) -> str | None:
    """Return the ratio as a percentage, or ``None`` when it is undefined."""
    if ratio is None:
        return None
    return percentage_display(ratio)


def _money_or_none(value: Decimal | None) -> str | None:
    """Return the amount as money, or ``None`` when there is no amount."""
    if value is None:
        return None
    return money_display(value)


def point_row(point: PayoffPoint, *, precision: int) -> Mapping[str, object]:
    """Render one point of the curve as display strings and a trend token.

    Args:
        point: The priced point, straight from the domain.
        precision: Decimal places for the price, from ``price_precision``.

    Returns:
        The row the model copies and a chart binds. ``positionValueDisplay``
        is ``None`` for a sale, which leaves no position to value
        (spec 0014 OD-12), and ``returnPctDisplay`` is ``None`` only for an
        order of zero size, which the tool rejects and the domain still
        represents honestly (spec 0014 OD-4).
    """
    return {
        "priceDisplay": money_display(point.price, precision=precision),
        "movePctDisplay": percentage_display(point.move_ratio),
        "positionValueDisplay": _money_or_none(point.position_value),
        "profitLossDisplay": signed_money_display(point.profit_loss),
        "returnPctDisplay": _percentage_or_none(point.return_ratio),
        "trend": trend_of(point.profit_loss),
    }


def order_block(curve: PayoffCurve, *, precision: int) -> Mapping[str, object]:
    """Render the order the curve prices — the order ticket's own figures.

    Args:
        curve: The priced curve.
        precision: Decimal places for prices, so the ticket and the ladder
            below it never print the same price two different ways.

    Returns:
        The block the ticket binds. ``side``, ``symbol`` and ``name`` are
        labels rather than figures; everything else is a display string.
    """
    return {
        "symbol": curve.symbol,
        "name": curve.name,
        "side": curve.side,
        "quantityDisplay": quantity_display(curve.quantity, trim=True),
        "entryPriceDisplay": money_display(curve.entry_price, precision=precision),
        "notionalDisplay": money_display(curve.notional),
        "breakEvenPriceDisplay": money_display(
            curve.break_even_price, precision=precision
        ),
    }


def scenarios(curve: PayoffCurve, *, precision: int) -> Mapping[str, object]:
    """Render the three points a reader asks about by name.

    Args:
        curve: The priced curve.
        precision: Decimal places for the price, from ``price_precision``.

    Returns:
        The low end of the plotted range, the entry, and the high end — the
        same rows as in ``points``, keyed so a sentence can name them without
        the model picking an index out of the array.
    """
    low, entry, high = curve.bracket()
    return {
        "low": point_row(low, precision=precision),
        "entry": point_row(entry, precision=precision),
        "high": point_row(high, precision=precision),
    }


__all__ = [
    "MAX_PRICE_PRECISION",
    "order_block",
    "point_row",
    "price_precision",
    "scenarios",
]
