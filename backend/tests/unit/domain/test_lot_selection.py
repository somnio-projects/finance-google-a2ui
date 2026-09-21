"""Spec 0013 AC-3, OD-8 — which lot a sale consumes first, and in what order."""

from datetime import date
from decimal import Decimal

import pytest

from app.domain.lot_selection import LotMethod, consumption_order, unit_cost
from app.domain.lots import TaxLot

METHOD_IDS = [method.value for method in LotMethod]


def build_lot(lot_id: str, *, day: int, cost_basis: str) -> TaxLot:
    """Build a one-unit lot on a given day of January 2026."""
    return TaxLot(
        lot_id=lot_id,
        symbol="NVDA",
        acquired_on=date(2026, 1, day),
        quantity=Decimal(1),
        cost_basis=Decimal(cost_basis),
    )


#: Three lots whose age order and whose price order disagree, so each method
#: picks a different one first — the only arrangement that can tell them apart.
OLDEST = build_lot("lot-a", day=1, cost_basis="100")
DEAREST = build_lot("lot-b", day=2, cost_basis="300")
NEWEST = build_lot("lot-c", day=3, cost_basis="200")

#: Deliberately unsorted: a passing test must be the ordering's doing.
SCRAMBLED = (DEAREST, NEWEST, OLDEST)


@pytest.mark.parametrize(
    ("method", "expected"),
    [
        (LotMethod.FIFO, ["lot-a", "lot-b", "lot-c"]),
        (LotMethod.LIFO, ["lot-c", "lot-b", "lot-a"]),
        (LotMethod.HIFO, ["lot-b", "lot-c", "lot-a"]),
    ],
    ids=["fifo_takes_the_oldest", "lifo_takes_the_newest", "hifo_takes_the_dearest"],
)
def test_each_method_orders_the_lots_its_own_way(
    method: LotMethod, expected: list[str]
) -> None:
    """AC-3 — the three policies disagree on every position of the order."""
    ordered = consumption_order(SCRAMBLED, method=method)

    assert [lot.lot_id for lot in ordered] == expected


def test_unit_cost_is_what_one_unit_of_the_lot_cost() -> None:
    """The figure HIFO ranks by, exact rather than rounded."""
    assert unit_cost(DEAREST) == Decimal(300)
    assert unit_cost(build_lot("lot-d", day=4, cost_basis="150")) == Decimal(150)


@pytest.mark.parametrize("method", list(LotMethod), ids=METHOD_IDS)
def test_lots_that_tie_are_ordered_by_id(method: LotMethod) -> None:
    """OD-8 — a tie resolves the same way under every method, every run.

    Same day and same unit cost, so date and price both tie and only the
    ``lot_id`` tie-break can decide. Built by hand rather than taken from the
    seed, because the point is that a tie is handled at all.
    """
    later_id = build_lot("lot-z", day=5, cost_basis="500")
    earlier_id = build_lot("lot-y", day=5, cost_basis="500")

    ordered = consumption_order([later_id, earlier_id], method=method)

    assert [lot.lot_id for lot in ordered] == ["lot-y", "lot-z"]


@pytest.mark.parametrize("method", list(LotMethod), ids=METHOD_IDS)
def test_the_caller_s_own_sequence_is_never_reordered(method: LotMethod) -> None:
    """A pure function hands back a new list and leaves the argument alone."""
    given = list(SCRAMBLED)

    consumption_order(given, method=method)

    assert given == list(SCRAMBLED)
