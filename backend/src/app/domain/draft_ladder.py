"""The stops a leg's slider can land on (spec 0050).

The design draws a draggable track beside every stepper. A slider is
continuous and this contract is not: the money total, the weight, the cash
remaining and every weight shift move with the value, and a client may compute
none of them (N-2). So the track is **quantised**: every stop is a whole
``legs`` option value written here, exactly as ``draft_legs.stepped`` writes
the stepper's two neighbours.

The two controls are **two granularities of one quantity**, not one ladder. A
tap moves the asset's own step; a drag moves one stride, which is that step
coarsened until the ladder fits ``MAX_LADDER``. An ``increment`` is therefore
generally not a stop of the track drawn beside it, and that is fine — the
ladder is aligned to the *current* value, so whichever control sent the move,
the next render puts the thumb on the number it sent.

That is the smallest honest shape, and the alternative was rejected rather than
missed. The frame's thumb sits at the leg's *weight* (40 % / 35 % / 25 %,
summing to 100), which reads as though the slider set the leg's share of the
order. It does not: a weight control would need a second option, its edits
would be **non-local** — moving one leg redistributes the others — and the row
would carry two controls governing two different quantities. The weight stays
what it already is, an output of the render (spec 0050 OD-1).

The ladder is aligned **to the current value**, not to zero, so the number on
screen is always a stop; zero and the ceiling are added so the ends are always
reachable. Its length is bounded, because a payload is not a place to put an
unbounded list.
"""

from dataclasses import dataclass
from decimal import Decimal
from typing import Final

from app.domain.draft_ceiling import ceiling
from app.domain.draft_impact import DraftImpact
from app.domain.draft_legs import LegRequest, format_legs, with_quantity
from app.domain.market import market_asset
from app.domain.money import ZERO
from app.domain.payoff import Side
from app.domain.portfolio import Portfolio

#: How many stops a track carries before it is thinned by a coarser stride.
#: Twenty-one puts a stop every 30 px on the design's 600 px track, which is
#: finer than a thumb can be placed and far short of a payload worth paging.
MAX_STOPS: Final[int] = 21
#: The bound the payload declares: the aligned ladder, plus the two ends.
MAX_LADDER: Final[int] = MAX_STOPS + 2
#: An index into a ladder, as the decimal string every number travels to the
#: client as (ADR-E D-5). Two digits, because ``MAX_LADDER`` is two digits.
POSITION_PATTERN: Final[str] = r"^[0-9]{1,2}$"


@dataclass(frozen=True, slots=True)
class Ladder:
    """One leg's stops, ascending, and where its current value sits."""

    stops: tuple[str, ...]
    position: str


def _units(current: Decimal, step: Decimal, top: Decimal) -> tuple[Decimal, ...]:
    """Return the ladder in units: aligned to ``current``, with both ends."""
    span = int(top / step) if step else 0
    stride = step * max(1, -(-(span + 1) // MAX_STOPS))
    values = {ZERO, top, current}
    offset = stride
    while current - offset > ZERO or current + offset < top:
        if current - offset > ZERO:
            values.add(current - offset)
        if current + offset < top:
            values.add(current + offset)
        offset += stride
    return tuple(sorted(values))


def ladder(
    portfolio: Portfolio,
    impact: DraftImpact,
    requests: tuple[LegRequest, ...],
    symbol: str,
    side: Side,
) -> Ladder:
    """Return every ``legs`` value this leg's track can send, and the current one.

    Args:
        portfolio: Passed through to :func:`ceiling`.
        impact: The priced legs this render was built from.
        requests: The legs as asked for — each stop is these with one moved.
        symbol: The leg the track belongs to.
        side: Which way the order goes.

    Returns:
        The stops ascending by this leg's units, and the index of the value
        on screen — which is always present, because the ladder is aligned
        to it.
    """
    current = next(leg.quantity for leg in requests if leg.symbol == symbol)
    top = ceiling(portfolio, impact, symbol, side)
    units = _units(current, market_asset(symbol).step, top)
    return Ladder(
        stops=tuple(
            format_legs(with_quantity(requests, symbol, value)) for value in units
        ),
        position=str(units.index(current)),
    )


# ``ceiling`` is re-exported: it moved out for the budget and every caller
# and test was already importing it from here.
__all__ = [
    "MAX_LADDER",
    "MAX_STOPS",
    "POSITION_PATTERN",
    "Ladder",
    "ceiling",
    "ladder",
]
