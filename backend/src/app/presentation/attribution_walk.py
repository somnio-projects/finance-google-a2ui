"""Building the steps and the sentences of the attribution walk.

Its own module for the reason ``order_sizing`` is one: the view is at the file
budget, and this is the seam that was already there — *how the walk is built*
apart from *what the projection is*. Pure, like everything in this layer.
"""

from collections.abc import Sequence
from decimal import Decimal
from itertools import accumulate
from typing import Final, Protocol

from app.domain.holdings import Holding
from app.presentation.displays import MoneyDisplay
from app.presentation.fragments import Annotation, Bucket

#: How many movers the chart names in words beside it.
ANNOTATED: Final[int] = 2


class Money(Protocol):
    """The one thing these builders need from an options model.

    A Protocol rather than the concrete ``AttributionWaterfallOptions``:
    importing the view would make this helper depend on the module that
    imports it. ``Any`` would also compile, and would silently stop
    checking ``options.money(...)`` under strict — the type the helpers
    had before they were split out.
    """

    def money(self, value: Decimal) -> MoneyDisplay:
        """Format ``value`` under this render's locale and precision."""
        ...


def buckets(
    rows: Sequence[Holding], *, start: Decimal, options: Money
) -> tuple[Bucket, ...]:
    """Walk each holding's unrealised P/L, carrying the running total."""
    running = accumulate((row.unrealized_pl for row in rows), initial=start)
    next(running)  # the opening balance is the chart's start, not a step
    return tuple(
        Bucket(
            # The ticker, not the name: this is the value a tap sends back as
            # the drill action's argument, and that argument accepts symbols.
            # `test_waterfall_events.py` compares the two declarations.
            key=row.symbol,
            label=row.name,
            delta=options.money(row.unrealized_pl),
            cumulative=options.money(total),
            direction="up" if row.unrealized_pl >= 0 else "down",
        )
        for row, total in zip(rows, running, strict=True)
    )


def notes(
    rows: Sequence[Holding], net: Decimal, options: Money
) -> tuple[Annotation, ...]:
    """Name the biggest movers and the net move, in words the widget shows."""
    movers = (
        Annotation(label=row.name, text=options.money(row.unrealized_pl).display)
        for row in rows[:ANNOTATED]
    )
    return (*movers, Annotation(label="Net", text=options.money(net).display))


__all__ = ["ANNOTATED", "Money", "buckets", "notes"]
