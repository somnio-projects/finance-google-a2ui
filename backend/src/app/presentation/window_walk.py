"""Building the steps, the headline and the sentences of a window walk.

Its own module for the reason ``attribution_walk`` is one: the view sits near
the 150-line budget and *how the walk is built* is a different concern from
*what the projection is*. Pure, like everything in this layer.

Every figure here is written from a ``Contribution`` — the domain's own
per-holding split of the move — so the bars sum to the headline by
construction. `domain/attribution.py` guarantees that and its tests assert it;
nothing in this module re-derives a total.
"""

from collections.abc import Sequence
from decimal import Decimal
from itertools import accumulate

from app.domain.attribution import Contribution
from app.domain.day_change import trend_of
from app.presentation.attribution_walk import ANNOTATED, move_of
from app.presentation.displays import signed_money
from app.presentation.fragments import Annotation, Delta
from app.presentation.options import DisplayOptions
from app.presentation.window_payload import NET_LABEL, WindowStep


def net_of(*, start: Decimal, end: Decimal, options: DisplayOptions) -> Delta:
    """The whole window in one signed figure — the headline pill."""
    delta = end - start
    return Delta(
        label=NET_LABEL,
        amount=signed_money(delta, precision=options.precision, locale=options.locale),
        percent=move_of(end, start, options),
        direction=trend_of(delta),
    )


def step_of(row: Contribution, total: Decimal, options: DisplayOptions) -> WindowStep:
    """Write one holding's contribution down as a step of the walk.

    The step names the two values the move is between, because "NVDA
    -$7,871.40" answers *how much* and not *from what*.
    """
    move = move_of(row.end_value, row.start_value, options)
    opened = options.money(row.start_value)
    closed = options.money(row.end_value)
    return WindowStep(
        # The ticker, not the name: a tap sends this back as the drill
        # argument, and that argument accepts symbols.
        key=row.symbol,
        label=row.name,
        delta=signed_money(
            row.contribution, precision=options.precision, locale=options.locale
        ),
        cumulative=options.money(total),
        direction="up" if row.contribution >= 0 else "down",
        move=move,
        opened=opened,
        closed=closed,
        detail=f"{move.display} · {opened.display} → {closed.display}",
        selected_label=f"{row.symbol} selected",
    )


def buckets(
    rows: Sequence[Contribution], *, start: Decimal, options: DisplayOptions
) -> tuple[WindowStep, ...]:
    """Walk each holding's contribution, carrying the running total."""
    running = accumulate((row.contribution for row in rows), initial=start)
    next(running)  # the opening balance is the chart's start, not a step
    return tuple(
        step_of(row, total, options) for row, total in zip(rows, running, strict=True)
    )


def notes(
    rows: Sequence[Contribution],
    net: Decimal,
    period: str,
    options: DisplayOptions,
) -> tuple[Annotation, ...]:
    """Name the biggest movers and the net move, in words the widget shows.

    The net annotation carries the **period**, because this walk's headline is
    only meaningful with one. That is the whole defect this view closes: a
    figure with no window beside a sentence that has one.
    """
    movers = (
        Annotation(
            label=row.name,
            text=signed_money(
                row.contribution, precision=options.precision, locale=options.locale
            ).display,
        )
        for row in rows[:ANNOTATED]
    )
    net_text = signed_money(
        net, precision=options.precision, locale=options.locale
    ).display
    return (*movers, Annotation(label=NET_LABEL, text=f"{net_text} {period}"))


__all__ = ["buckets", "net_of", "notes", "step_of"]
