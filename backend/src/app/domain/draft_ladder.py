"""The stops a leg's slider can land on (spec 0050).

The design draws a draggable track beside every stepper, and its thumb sits at
the leg's **weight in the order** — 40 % / 35 % / 25 % on the frame's three
legs, summing to 100. So the slider sets the **mix**, and the stepper sets the
**size**: a drag moves one leg's share while the order's total stays where it
is, and the rest of the basket takes up the difference in its own proportions.

That reading was not the first one. The ladder was built to walk **units**,
which fits the stepper and is the smaller contract change — and then the client
work measured what it would look like: the same three legs weigh 39.44 / 35.61
/ 24.95 %, while their unit ladders put the thumb at 10.5 / 10.0 / 9.1 %. A
handle at 10 % beside a label reading 39.44 % is a screen that contradicts
itself, so *"the thumb is the weight"* is not a detail of the artboard, it is
what the control **is** (spec 0050 OD-1).

A slider is continuous and this contract is not: the total, the cash remaining
and every weight shift move with the value, and a client may compute none of
them (N-2). So the track is **quantised** and every stop is a whole ``legs``
option value written here, exactly as ``draft_legs.stepped`` writes the
stepper's two neighbours. The ladder is aligned to the **current** weight, so
the number on screen is always a stop, and both ends are added so a leg can be
taken to nothing or given the whole order.
"""

from dataclasses import dataclass
from decimal import Decimal
from typing import Final

from app.domain.draft_legs import LegRequest, format_legs
from app.domain.draft_rebalance import at_weight, notionals
from app.domain.money import ZERO

#: How many stops a track carries. Twenty-one is a stop every five points of
#: weight, which is finer than a thumb can be placed on the design's track.
MAX_STOPS: Final[int] = 21
#: The bound the payload declares: the aligned ladder, plus the two ends.
MAX_LADDER: Final[int] = MAX_STOPS + 2
#: An index into a ladder, as the decimal string every number travels to the
#: client as (ADR-E D-5). Two digits, because ``MAX_LADDER`` is two digits.
POSITION_PATTERN: Final[str] = r"^[0-9]{1,2}$"

#: One whole order. A weight is a fraction of it, never a percentage here.
ONE: Final[Decimal] = Decimal(1)
#: The stride between stops, as a fraction: five points of weight.
STRIDE: Final[Decimal] = ONE / (MAX_STOPS - 1)


@dataclass(frozen=True, slots=True)
class Ladder:
    """One leg's stops, ascending by its weight, and where it sits now."""

    stops: tuple[str, ...]
    position: str


def _weights(current: Decimal) -> tuple[Decimal, ...]:
    """Return the ladder in weights: aligned to ``current``, with both ends."""
    values = {ZERO, ONE, current}
    offset = STRIDE
    while current - offset > ZERO or current + offset < ONE:
        if current - offset > ZERO:
            values.add(current - offset)
        if current + offset < ONE:
            values.add(current + offset)
        offset += STRIDE
    return tuple(sorted(values))


def ladder(requests: tuple[LegRequest, ...], symbol: str) -> Ladder:
    """Return every ``legs`` value this leg's track can send, and the current one.

    A draft worth nothing, or one whose other legs are all zero, has no mix to
    move: the ladder is the single stop it already sits on, and the client
    draws a track that cannot be dragged rather than one that redistributes
    nothing.

    Args:
        requests: The legs as asked for — each stop is these, rebalanced.
        symbol: The leg the track belongs to.

    Returns:
        The stops ascending by this leg's weight, and the index of the value
        on screen — always present, because the ladder is aligned to it.
    """
    values = notionals(requests)
    total = sum(values.values(), ZERO)
    others = total - values[symbol]
    if total <= ZERO or others <= ZERO:
        return Ladder(stops=(format_legs(requests),), position="0")
    current = values[symbol] / total
    weights = _weights(current)
    here = format_legs(requests)
    return Ladder(
        # The stop the thumb is on is the value the caller sent, **verbatim**.
        # Rebalancing to the weight it already has would round-trip through
        # eight decimals and answer `BTC:0.06000000` where the option in
        # effect says `BTC:0.06` — the same number, a different string, and
        # the client compares strings.
        stops=tuple(
            here if value == current else at_weight(requests, symbol, value)
            for value in weights
        ),
        position=str(weights.index(current)),
    )


__all__ = [
    "MAX_LADDER",
    "MAX_STOPS",
    "POSITION_PATTERN",
    "Ladder",
    "ladder",
]
