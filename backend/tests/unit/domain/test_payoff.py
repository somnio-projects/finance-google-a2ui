"""Spec 0014 — the arithmetic a payoff curve is made of.

Everything here is asserted against hand-computed ``Decimal`` values, never
against a number parsed back out of a display string: the display layer is
tested where it lives, and a test that reads its own output proves nothing.
"""

from decimal import Decimal
from itertools import pairwise

import pytest

from app.domain.errors import PayoffRangeError
from app.domain.money import ONE, ZERO
from app.domain.payoff import PayoffCurve, Side
from app.domain.payoff_pricing import order_quantity, payoff_curve

ENTRY = Decimal("152.40")
QUANTITY = Decimal("40")
RANGE_PCT = 30
STEPS = 12


def build(
    *, side: Side = "buy", quantity: Decimal = QUANTITY, steps: int = STEPS
) -> PayoffCurve:
    """Return a curve over the seeded SOL price, varying one thing at a time."""
    return payoff_curve(
        symbol="SOL",
        name="Solana",
        entry_price=ENTRY,
        quantity=quantity,
        side=side,
        range_pct=RANGE_PCT,
        steps=steps,
    )


def test_the_entry_price_is_a_grid_point_where_nothing_is_made_or_lost() -> None:
    """AC-2, OD-2 — exactly zero, because the entry is sampled, not straddled."""
    _, entry, _ = build().bracket()

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
    """AC-2, OD-6 — the sign flips and nothing else does."""
    bought = build(side="buy").points
    sold = build(side="sell").points

    assert [point.price for point in sold] == [point.price for point in bought]
    assert [point.profit_loss for point in sold] == [
        -point.profit_loss for point in bought
    ]


def test_each_point_equals_the_hand_computed_profit() -> None:
    """AC-3 — ``(price - entry) * quantity``, point by point."""
    for point in build().points:
        assert point.profit_loss == (point.price - ENTRY) * QUANTITY
        assert point.position_value == point.price * QUANTITY


def test_break_even_is_the_entry_price_for_a_fee_free_order() -> None:
    """AC-3, OD-9 — its own field, equal to the entry until a fee exists."""
    curve = build()

    assert curve.break_even_price == curve.entry_price
    assert curve.notional == ENTRY * QUANTITY


def test_the_grid_is_symmetric_around_the_entry_price() -> None:
    """OD-2 — ``2 * steps + 1`` points, the ends exactly ``±range_pct``."""
    curve = build()
    low, _, high = curve.bracket()

    assert len(curve.points) == 2 * STEPS + 1
    assert low.price == ENTRY * (ONE - Decimal("0.30"))
    assert high.price == ENTRY * (ONE + Decimal("0.30"))
    assert low.move_ratio == -high.move_ratio


@pytest.mark.parametrize(
    ("side", "sign"), [("buy", ONE), ("sell", -ONE)], ids=["buy", "sell"]
)
def test_the_return_on_the_order_is_the_price_move_signed_by_the_side(
    side: Side, sign: Decimal
) -> None:
    """The two ratios coincide for a linear spot payoff — pinned, not assumed.

    Nobody should later "fix" one of them into a different number; if a fee
    or a financing cost ever lands, this is the test that notices.
    """
    for point in build(side=side).points:
        assert point.return_ratio == sign * point.move_ratio


def test_an_order_of_zero_size_makes_nothing_and_returns_nothing() -> None:
    """OD-4 — the domain represents it; the tool is what refuses to ask it."""
    curve = build(quantity=ZERO)

    assert curve.notional == ZERO
    assert all(point.profit_loss == ZERO for point in curve.points)
    assert all(point.return_ratio is None for point in curve.points)


@pytest.mark.parametrize("steps", [0, -3], ids=["no_steps", "negative_steps"])
def test_a_curve_needs_at_least_one_step_on_each_side(steps: int) -> None:
    """AC-7 — refused outright, rather than answered with a single point."""
    with pytest.raises(PayoffRangeError, match="at least 1 step per side"):
        build(steps=steps)


def test_a_dollar_amount_buys_exactly_what_it_pays_for() -> None:
    """AC-4 — the division the model must never do, done here."""
    assert order_quantity(Decimal(500), Decimal(100)) == Decimal(5)


def test_the_units_a_dollar_amount_buys_are_worth_that_amount_again() -> None:
    """AC-4 — round-tripped through a price that does not divide evenly."""
    units = order_quantity(Decimal(500), ENTRY)

    assert abs(units * ENTRY - Decimal(500)) < Decimal("0.00000001")
