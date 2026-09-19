"""Spec 0014 — the arithmetic a payoff curve is made of.

Asserted against hand-computed ``Decimal`` values, never against a number
parsed back out of a display string: a test that reads its own output proves
nothing.
"""

from decimal import Decimal
from itertools import pairwise

import pytest

from app.domain.errors import PayoffRangeError
from app.domain.money import ONE, ZERO
from tests.unit.domain.payoff_fixtures import ENTRY, build


@pytest.mark.parametrize(
    ("range_pct", "steps"),
    [(5, 1), (5, 25), (30, 12), (90, 1), (90, 25), (7, 3)],
    ids=[
        "narrowest_and_coarsest",
        "narrowest_and_finest",
        "the_defaults",
        "widest_and_coarsest",
        "widest_and_finest",
        "a_range_that_does_not_divide_evenly",
    ],
)
def test_the_entry_price_is_a_grid_point_where_nothing_is_made_or_lost(
    range_pct: int, steps: int
) -> None:
    """AC-2, OD-2 — exactly zero, because the entry is sampled, not straddled.

    Across the corners of the bound space and one range that does not divide
    evenly: the spec leans on this equality harder than on anything else.
    """
    curve = build(range_pct=range_pct, steps=steps)

    _, entry, _ = curve.bracket()
    assert len(curve.points) == 2 * steps + 1
    assert entry.price == ENTRY
    assert entry.move_ratio == ZERO
    assert entry.profit_loss == ZERO
    assert entry.return_ratio == ZERO


def test_a_long_gains_with_every_step_up() -> None:
    """AC-2 — strictly monotonic, so the chart has no flat shelf to misread."""
    points = build().points

    prices = [point.price for point in points]
    profits = [point.profit_loss for point in points]
    assert prices == sorted(prices)
    assert all(later > earlier for earlier, later in pairwise(profits))


def test_a_sell_is_the_mirror_of_the_buy() -> None:
    """AC-2, OD-6 — the sign flips and the prices do not."""
    bought = build(side="buy").points
    sold = build(side="sell").points

    assert [point.price for point in sold] == [point.price for point in bought]
    assert [point.profit_loss for point in sold] == [
        -point.profit_loss for point in bought
    ]


def test_the_grid_is_symmetric_around_the_entry_price() -> None:
    """OD-2 — the ends are exactly ``±range_pct``, and the step says how far."""
    curve = build()
    low, _, high = curve.bracket()

    assert low.price == ENTRY * (ONE - Decimal("0.30"))
    assert high.price == ENTRY * (ONE + Decimal("0.30"))
    assert low.move_ratio == -high.move_ratio
    assert curve.price_step == high.price - curve.points[-2].price


@pytest.mark.parametrize("steps", [0, -3], ids=["no_steps", "negative_steps"])
def test_a_curve_needs_at_least_one_step_on_each_side(steps: int) -> None:
    """AC-7 — refused outright, rather than answered with a single point."""
    with pytest.raises(PayoffRangeError, match="at least 1 step per side"):
        build(steps=steps)
