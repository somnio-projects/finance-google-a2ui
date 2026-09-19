"""Which tax lot a sale consumes first (spec 0013 §2, OD-8).

Its own module because it is a *policy*, separable from what selling a lot
does: a fourth method is a fourth entry in ``ORDERINGS`` and touches nothing
in ``app.domain.sales``. The same seam ADR-K D-15 asks for, one layer down.

**Every order is total.** Each one ends in ``lot_id`` ascending, so two lots
acquired on the same day — or carrying the same unit cost under HIFO — consume
in a fixed order rather than in whatever order the seed happened to list them.
Determinism has to be structural; a demo that reorders itself because two lots
tie is a demo nobody can hand-check.
"""

from collections.abc import Callable, Sequence
from decimal import Decimal
from enum import StrEnum
from typing import Final

from app.domain.lots import TaxLot


class LotMethod(StrEnum):
    """How a sale picks which open lots to consume."""

    FIFO = "FIFO"
    LIFO = "LIFO"
    HIFO = "HIFO"


def unit_cost(lot: TaxLot) -> Decimal:
    """Return what one unit of ``lot`` cost.

    Args:
        lot: An open tax lot; its quantity is ``gt=0``, so this cannot divide
            by zero.

    Returns:
        ``cost_basis / quantity`` as an exact ``Decimal``.
    """
    return lot.cost_basis / lot.quantity


def _oldest_first(lots: Sequence[TaxLot]) -> list[TaxLot]:
    """Order by acquisition date ascending — FIFO."""
    return sorted(lots, key=lambda lot: (lot.acquired_on, lot.lot_id))


def _newest_first(lots: Sequence[TaxLot]) -> list[TaxLot]:
    """Order by acquisition date descending — LIFO.

    The date is negated through ``toordinal`` rather than sorting in reverse,
    because ``reverse=True`` would flip the ``lot_id`` tie-break with it and
    leave the order looking total while behaving differently on each side.
    """
    return sorted(lots, key=lambda lot: (-lot.acquired_on.toordinal(), lot.lot_id))


def _dearest_first(lots: Sequence[TaxLot]) -> list[TaxLot]:
    """Order by cost per unit descending — HIFO, the smallest gain first."""
    return sorted(lots, key=lambda lot: (-unit_cost(lot), lot.lot_id))


#: Consumption order per method. A dict, not an ``if/elif``: adding a method
#: is one entry and one test, and nothing else in the package knows the list.
ORDERINGS: Final[dict[LotMethod, Callable[[Sequence[TaxLot]], list[TaxLot]]]] = {
    LotMethod.FIFO: _oldest_first,
    LotMethod.LIFO: _newest_first,
    LotMethod.HIFO: _dearest_first,
}


def consumption_order(lots: Sequence[TaxLot], *, method: LotMethod) -> list[TaxLot]:
    """Return ``lots`` in the order ``method`` consumes them.

    Args:
        lots: The open lots of one symbol, in any order.
        method: Which lot-selection policy the caller asked for.

    Returns:
        A new list; the input is never reordered in place.
    """
    return ORDERINGS[method](lots)


__all__ = ["ORDERINGS", "LotMethod", "consumption_order", "unit_cost"]
