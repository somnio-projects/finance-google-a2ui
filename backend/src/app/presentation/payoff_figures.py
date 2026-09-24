"""How a payoff curve is written down (spec 0016).

``views/payoff_curve.py`` is the projection — its id, its DTO and its
registration; ``payoff_order`` is what the caller may ask for. This module is
the shaping in between: **one** price resolution for the whole payload, and
the fragments the DTO is built from.

It sits beside ``views/`` for the same reason ``payoff_order`` does: every
module in that package is a registered view (spec 0016 OD-5).

Pure, like everything in this package. It formats what the domain already
computed and computes nothing of its own.
"""

from dataclasses import dataclass
from decimal import Decimal
from typing import Final

from app.core.display import MONEY_PRECISION, PRICE_PRECISION, QUANTITY_PRECISION
from app.core.locales import quantize
from app.domain.payoff import PayoffCurve, PayoffPoint
from app.presentation.fragments import (
    Annotation,
    MoneyDisplay,
    Series,
    SeriesPoint,
    Total,
    money,
)

SERIES_NAME: Final[str] = "Profit / loss"


@dataclass(frozen=True, slots=True)
class Shape:
    """How one payload writes its numbers down, decided once per render."""

    places: int
    precision: int
    locale: str


def price_places(*, step: Decimal, entry: Decimal) -> int:
    """Return the decimal places every price in one payload is quoted to.

    Two rules together. A unit price is quoted to the resolution it is
    actually quoted at — ``app.core.display.price_display``'s rule, which is
    why XOM is not printed as ``$0.13``. The grid's own step then widens that
    when the step is finer, because a ladder whose adjacent rows render the
    same price states two contradictory things at once (spec 0014 OD-10).

    Args:
        step: Distance between two adjacent grid prices; always positive.
        entry: The price the order is struck at.

    Returns:
        One number for the whole payload, between ``MONEY_PRECISION`` and
        ``QUANTITY_PRECISION``, so the entry, the break-even and every point
        of the line are printed the same way (spec 0016 OD-4).
    """
    quoted = (
        MONEY_PRECISION
        if entry == quantize(entry, precision=MONEY_PRECISION)
        else PRICE_PRECISION
    )
    return min(max(quoted, -step.adjusted()), QUANTITY_PRECISION)


def price(value: Decimal, shape: Shape) -> MoneyDisplay:
    """Return a unit price at this payload's own resolution."""
    return money(value, precision=shape.places, locale=shape.locale)


def amount(value: Decimal, shape: Shape) -> MoneyDisplay:
    """Return a money figure at the precision the caller asked for."""
    return money(value, precision=shape.precision, locale=shape.locale)


def totals(curve: PayoffCurve, shape: Shape) -> tuple[Total, ...]:
    """Return the entry price, the break-even price and the notional.

    The break-even keeps a field of its own although a fee-free spot order
    puts it exactly on the entry: a consumer that binds it keeps working the
    day a fee moves it (spec 0014 OD-9).
    """
    return (
        Total(label="Entry price", amount=price(curve.entry_price, shape)),
        Total(label="Break-even price", amount=price(curve.break_even_price, shape)),
        Total(label="Notional", amount=amount(curve.notional, shape)),
    )


def line(curve: PayoffCurve, shape: Shape) -> Series:
    """Return the profit-and-loss line, one point per grid price.

    Each point carries its price twice over: ``at`` is the ADR-E pair a
    painter reads the x coordinate from, ``label`` the tick it prints. Before
    GGU-53 only the label shipped, so the curve could be labelled but not
    plotted — the client had to parse the formatted price back into a number.
    """
    at = [price(point.price, shape) for point in curve.points]
    return Series(
        name=SERIES_NAME,
        points=tuple(
            SeriesPoint(
                at=where, label=where.display, value=amount(point.profit_loss, shape)
            )
            for point, where in zip(curve.points, at, strict=True)
        ),
    )


def _end(point: PayoffPoint, shape: Shape) -> str:
    """Return one end of the plotted range as ``at <price>: <profit>``."""
    where = price(point.price, shape).display
    made = amount(point.profit_loss, shape).display
    return f"at {where}: {made}"


def notes(curve: PayoffCurve, shape: Shape) -> tuple[Annotation, ...]:
    """Mark the entry, the break-even and the two ends of the plotted range.

    Annotations are the chart vocabulary the first projections established, so
    two markers do not arrive as a third mechanism (ADR-K D-16).
    """
    low, entry, high = curve.bracket()
    return (
        Annotation(label="Entry", text=price(entry.price, shape).display),
        Annotation(
            label="Break-even", text=price(curve.break_even_price, shape).display
        ),
        Annotation(label="Low", text=_end(low, shape)),
        Annotation(label="High", text=_end(high, shape)),
    )


__all__ = [
    "SERIES_NAME",
    "Shape",
    "amount",
    "line",
    "notes",
    "price",
    "price_places",
    "totals",
]
