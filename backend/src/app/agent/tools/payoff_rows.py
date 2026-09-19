"""Display shaping for ``payoff`` (spec 0014 §3).

The other half of the tool: ``payoff_order`` decides *what was asked*, this
decides *how the answer reads*, and ``payoff`` is the tool. Split under the
150-line budget along that seam rather than by size, the same way the holdings
tool is.

Every function here is pure and returns nothing but strings and the trend
token, so "did a raw number escape into the payload?" is a question about this
file alone. It registers no tool: ``load_tools()`` imports it and nothing
happens, which is the cost of keeping a tool's helper beside the tool instead
of in a shared file (spec 0006 AC-7).
"""

from collections.abc import Mapping
from decimal import Decimal

from app.core.display import (
    money_display,
    percentage_display,
    quantity_display,
    signed_money_display,
)
from app.core.trend import trend_of
from app.domain.payoff import PayoffCurve, PayoffPoint


def _return_display(ratio: Decimal | None) -> str | None:
    """Return the ratio as a percentage, or ``None`` when it is undefined."""
    if ratio is None:
        return None
    return percentage_display(ratio)


def point_row(point: PayoffPoint) -> Mapping[str, object]:
    """Render one point of the curve as display strings and a trend token.

    Args:
        point: The priced point, straight from the domain.

    Returns:
        The row the model copies and a chart binds. ``returnPctDisplay`` is
        ``None`` only for an order of zero size, which the tool rejects and
        the domain still represents honestly (spec 0014 OD-4).
    """
    return {
        "priceDisplay": money_display(point.price),
        "movePctDisplay": percentage_display(point.move_ratio),
        "positionValueDisplay": money_display(point.position_value),
        "profitLossDisplay": signed_money_display(point.profit_loss),
        "returnPctDisplay": _return_display(point.return_ratio),
        "trend": trend_of(point.profit_loss),
    }


def order_block(curve: PayoffCurve) -> Mapping[str, object]:
    """Render the order the curve prices — the order ticket's own figures.

    Args:
        curve: The priced curve.

    Returns:
        The block the ticket binds. ``side``, ``symbol`` and ``name`` are
        labels rather than figures; everything else is a display string.
    """
    return {
        "symbol": curve.symbol,
        "name": curve.name,
        "side": curve.side,
        "quantityDisplay": quantity_display(curve.quantity, trim=True),
        "entryPriceDisplay": money_display(curve.entry_price),
        "notionalDisplay": money_display(curve.notional),
        "breakEvenPriceDisplay": money_display(curve.break_even_price),
    }


def scenarios(curve: PayoffCurve) -> Mapping[str, object]:
    """Render the three points a reader asks about by name.

    Args:
        curve: The priced curve.

    Returns:
        The low end of the plotted range, the entry, and the high end — the
        same rows as in ``points``, keyed so a sentence can name them without
        the model picking an index out of the array.
    """
    low, entry, high = curve.bracket()
    return {
        "low": point_row(low),
        "entry": point_row(entry),
        "high": point_row(high),
    }


__all__ = ["order_block", "point_row", "scenarios"]
