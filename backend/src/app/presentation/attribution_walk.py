"""Building the steps, the headline and the sentences of the attribution walk.

Its own module for the reason ``order_sizing`` is one: the view is at the file
budget, and this is the seam that was already there — *how the walk is built*
apart from *what the projection is*. Pure, like everything in this layer.

Typed against ``DisplayOptions``, the mixin every view's options model
composes, rather than the view's own class: importing the view here would
make this helper depend on the module that imports it.
"""

from collections.abc import Sequence
from decimal import Decimal
from itertools import accumulate
from typing import Final

from app.domain.day_change import change_ratio, trend_of
from app.domain.holdings import Holding
from app.presentation.attribution_payload import (
    DELTA_LABEL,
    NET_LABEL,
    HoldingStep,
)
from app.presentation.displays import PercentageDisplay, signed_money, signed_percentage
from app.presentation.fragments import Annotation, Delta
from app.presentation.options import DisplayOptions
from app.presentation.ticket_displays import price, quantity

#: How many movers the chart names in words beside it.
ANNOTATED: Final[int] = 2


def move_of(
    current: Decimal, base: Decimal, options: DisplayOptions
) -> PercentageDisplay:
    """The signed ratio of ``current`` against ``base``, under ``options``."""
    return signed_percentage(
        change_ratio(current, base), precision=options.precision, locale=options.locale
    )


def net_of(*, start: Decimal, end: Decimal, options: DisplayOptions) -> Delta:
    """The whole walk in one signed figure — the headline pill (GGU-100 AC-1)."""
    delta = end - start
    return Delta(
        label=NET_LABEL,
        amount=signed_money(delta, precision=options.precision, locale=options.locale),
        percent=move_of(end, start, options),
        direction=trend_of(delta),
    )


def step_of(row: Holding, total: Decimal, options: DisplayOptions) -> HoldingStep:
    """Write one holding's step down, with what its selected state shows."""
    move = move_of(row.market_value, row.cost_basis, options)
    units = quantity(row.quantity, locale=options.locale)
    unit_price = price(row.price, locale=options.locale)
    return HoldingStep(
        # The ticker, not the name: this is the value a tap sends back as
        # the drill action's argument, and that argument accepts symbols.
        # `test_waterfall_events.py` compares the two declarations.
        key=row.symbol,
        label=row.name,
        delta=options.money(row.unrealized_pl),
        cumulative=options.money(total),
        direction="up" if row.unrealized_pl >= 0 else "down",
        move=move,
        units=units,
        price=unit_price,
        # The unit word is the asset's own ticker: there is no "sh" in a
        # quantity of Bitcoin (GGU-122, spec 0046 OD-1).
        detail=f"{move.display} · {units.display} {row.symbol} · {unit_price.display}",
        delta_label=DELTA_LABEL,
    )


def buckets(
    rows: Sequence[Holding], *, start: Decimal, options: DisplayOptions
) -> tuple[HoldingStep, ...]:
    """Walk each holding's unrealised P/L, carrying the running total."""
    running = accumulate((row.unrealized_pl for row in rows), initial=start)
    next(running)  # the opening balance is the chart's start, not a step
    return tuple(
        step_of(row, total, options) for row, total in zip(rows, running, strict=True)
    )


def notes(
    rows: Sequence[Holding], net: Decimal, options: DisplayOptions
) -> tuple[Annotation, ...]:
    """Name the biggest movers and the net move, in words the widget shows."""
    movers = (
        Annotation(label=row.name, text=options.money(row.unrealized_pl).display)
        for row in rows[:ANNOTATED]
    )
    return (*movers, Annotation(label=NET_LABEL, text=options.money(net).display))


__all__ = ["ANNOTATED", "buckets", "move_of", "net_of", "notes", "step_of"]
