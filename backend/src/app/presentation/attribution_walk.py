"""Building the steps and the sentences of the attribution walk.

Its own module for the reason ``order_sizing`` is one: the view is at the file
budget, and this is the seam that was already there — *how the walk is built*
apart from *what the projection is*. Pure, like everything in this layer.
"""

from collections.abc import Sequence
from decimal import Decimal
from itertools import accumulate
from typing import Any, Final

from app.domain.holdings import Holding
from app.presentation.fragments import Annotation, Bucket

#: How many movers the chart names in words beside it.
ANNOTATED: Final[int] = 2


def buckets(
    rows: Sequence[Holding], *, start: Decimal, options: Any
) -> tuple[Bucket, ...]:
    """Walk each holding's unrealised P/L, carrying the running total."""
    running = accumulate((row.unrealized_pl for row in rows), initial=start)
    next(running)  # the opening balance is the chart's start, not a step
    return tuple(
        Bucket(
            label=row.name,
            delta=options.money(row.unrealized_pl),
            cumulative=options.money(total),
            direction="up" if row.unrealized_pl >= 0 else "down",
        )
        for row, total in zip(rows, running, strict=True)
    )


def notes(
    rows: Sequence[Holding], net: Decimal, options: Any
) -> tuple[Annotation, ...]:
    """Name the biggest movers and the net move, in words the widget shows."""
    movers = (
        Annotation(label=row.name, text=options.money(row.unrealized_pl).display)
        for row in rows[:ANNOTATED]
    )
    return (*movers, Annotation(label="Net", text=options.money(net).display))


__all__ = ["ANNOTATED", "buckets", "notes"]
