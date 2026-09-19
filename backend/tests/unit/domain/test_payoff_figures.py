"""Spec 0014 — the figures a payoff curve carries at each point.

``test_payoff`` covers the shape of the grid; this covers what every point
says. Asserted against hand-computed ``Decimal`` values, never against a
number parsed back out of a display string.
"""

from decimal import Decimal

import pytest

from app.domain.money import ONE, ZERO
from app.domain.payoff import Side
from tests.unit.domain.payoff_fixtures import ENTRY, QUANTITY, build


def test_a_purchase_has_a_position_to_value_and_a_sale_does_not() -> None:
    """OD-12 — the field that contradicted the profit beside it on a sale.

    ``quantity * price`` rises exactly where a sale's profit falls: it is not
    a worse number there, it is a number about something that does not exist.
    """
    for point in build(side="buy").points:
        assert point.position_value == point.price * QUANTITY
    assert all(point.position_value is None for point in build(side="sell").points)


def test_each_point_equals_the_hand_computed_profit() -> None:
    """AC-3 — ``(price - entry) * quantity``, point by point."""
    for point in build().points:
        assert point.profit_loss == (point.price - ENTRY) * QUANTITY


def test_break_even_is_the_entry_price_for_a_fee_free_order() -> None:
    """AC-3, OD-9 — its own field, equal to the entry until a fee exists."""
    curve = build()

    assert curve.break_even_price == curve.entry_price
    assert curve.notional == ENTRY * QUANTITY


@pytest.mark.parametrize(
    ("side", "sign"), [("buy", ONE), ("sell", -ONE)], ids=["buy", "sell"]
)
def test_the_return_on_the_order_is_the_price_move_signed_by_the_side(
    side: Side, sign: Decimal
) -> None:
    """The two ratios coincide for a linear spot payoff — pinned, not assumed.

    If a fee or a financing cost ever lands, this is the test that notices.
    """
    for point in build(side=side).points:
        assert point.return_ratio == sign * point.move_ratio


def test_an_order_of_zero_size_makes_nothing_and_returns_nothing() -> None:
    """OD-4 — the domain represents it; the tool is what refuses to ask it."""
    curve = build(quantity=ZERO)

    assert curve.notional == ZERO
    assert all(point.profit_loss == ZERO for point in curve.points)
    assert all(point.return_ratio is None for point in curve.points)
