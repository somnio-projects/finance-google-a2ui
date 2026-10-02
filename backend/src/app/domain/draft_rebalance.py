"""What the draft looks like with one leg at a given share (spec 0050).

Split from ``draft_ladder`` at the file budget, along the seam that was
already there: **what one stop is** — the basket rebalanced so a leg carries a
chosen weight, the total unchanged — apart from **which stops there are**.

The rest of the basket keeps its own proportions and absorbs the difference,
which is what makes the weights the ticket prints sum to one.
"""

from dataclasses import replace
from decimal import Decimal
from typing import Final

from app.domain.draft_legs import LegRequest, format_legs
from app.domain.market import market_asset
from app.domain.money import ZERO

#: The digits a rebalanced quantity is written with — the eight the ``legs``
#: pattern admits, so every stop is a value the options model takes back.
UNITS: Final[Decimal] = Decimal("0.00000001")


def notionals(requests: tuple[LegRequest, ...]) -> dict[str, Decimal]:
    """Return what each leg is worth at the reference price."""
    return {
        leg.symbol: leg.quantity * market_asset(leg.symbol).price for leg in requests
    }


def _written(value: Decimal) -> Decimal:
    """Return ``value`` as the ``legs`` pattern admits it.

    ``quantize`` writes a zero as ``0E-8``, which ``format_legs`` would put
    into the option verbatim and the pattern would refuse — a stop the backend
    itself cannot take back. Both ends of every ladder are a zero, so this is
    not an edge case: it is two of every twenty-three stops.
    """
    written = value.quantize(UNITS)
    return written or ZERO


def at_weight(requests: tuple[LegRequest, ...], symbol: str, weight: Decimal) -> str:
    """Write the draft with ``symbol`` at ``weight``, the total unchanged.

    The rest of the basket keeps its own proportions and absorbs the
    difference, which is what makes the weights on screen sum to one.

    Args:
        requests: The legs as asked for.
        symbol: The leg being moved.
        weight: Its target share of the order, ``0 <= weight <= 1``.

    Returns:
        The whole ``legs`` option value, every quantity written to the eight
        decimals the pattern admits.
    """
    values = notionals(requests)
    total = sum(values.values(), ZERO)
    others = total - values[symbol]
    target = total * weight
    share = (total - target) / others if others > ZERO else ZERO
    moved = tuple(
        replace(
            leg,
            quantity=_written(
                target / market_asset(symbol).price
                if leg.symbol == symbol
                else leg.quantity * share
            ),
        )
        for leg in requests
    )
    return format_legs(moved)


__all__ = ["UNITS", "at_weight", "notionals"]
