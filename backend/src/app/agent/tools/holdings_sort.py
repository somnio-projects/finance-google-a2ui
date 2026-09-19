"""The orders ``get_holdings_summary`` can rank its positions in.

A table, not an ``if/elif``: a new order is a new entry, and the key set of
this dict is what the model's JSON Schema enumerates, so the two cannot
disagree about which orders exist.

Every order is **total** — each key ends in the symbol, which is unique per
aggregated position — because an answer that reorders itself between two
identical calls is not deterministic (spec 0011 AC-5).
"""

from collections.abc import Callable, Sequence
from decimal import Decimal
from typing import Final, Literal

from app.domain.holdings import Holding
from app.domain.money import ZERO
from app.domain.returns import return_on_cost

SortBy = Literal["weight", "value", "gainers", "losers"]
DEFAULT_SORT: Final[SortBy] = "weight"

#: The orders that rank by size. Only these agree with what the allocation
#: chart draws, which is why only these carry a render intent (spec 0011 OD-1).
SIZE_ORDERS: Final[frozenset[str]] = frozenset({"weight", "value"})


def return_key(holding: Holding, *, descending: bool) -> tuple[bool, Decimal, str]:
    """Return the sort key ranking a position by its return on cost.

    Args:
        holding: The position to rank.
        descending: True for best-first, False for worst-first.

    Returns:
        A total key. A position with no cost basis has no return (spec 0011
        OD-2), and the leading flag sorts it **last in both directions** —
        it cannot be called a top gainer or a top loser, and dropping it
        would hide a position the user holds.
    """
    ratio = return_on_cost(holding.unrealized_pl, holding.cost_basis)
    value = ZERO if ratio is None else ratio
    return (ratio is None, -value if descending else value, holding.symbol)


def by_value(rows: Sequence[Holding]) -> list[Holding]:
    """Order by market value descending — which is also weight descending."""
    return sorted(rows, key=lambda item: (-item.market_value, item.symbol))


#: Row order per ``sort_by``. ``weight`` and ``value`` are the same ordering by
#: construction: weight is market value over a total that does not vary within
#: one call (spec 0011 OD-4).
SORTERS: Final[dict[str, Callable[[Sequence[Holding]], list[Holding]]]] = {
    "weight": by_value,
    "value": by_value,
    "gainers": lambda rows: sorted(rows, key=lambda h: return_key(h, descending=True)),
    "losers": lambda rows: sorted(rows, key=lambda h: return_key(h, descending=False)),
}

__all__ = ["DEFAULT_SORT", "SIZE_ORDERS", "SORTERS", "SortBy", "by_value", "return_key"]
