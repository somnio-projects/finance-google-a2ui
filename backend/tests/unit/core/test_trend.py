"""Spec 0011 AC-6 — the arrow and the number it sits beside must agree."""

from decimal import Decimal

import pytest

from app.core.display import signed_money_display
from app.core.trend import DOWN, FLAT, UP, trend_of


@pytest.mark.parametrize(
    ("value", "expected"),
    [
        (Decimal("266.00"), UP),
        (Decimal("-266.00"), DOWN),
        (Decimal(0), FLAT),
    ],
    ids=["gain", "loss", "exactly_zero"],
)
def test_trend_of_names_the_direction_of_the_figure(
    value: Decimal, expected: str
) -> None:
    assert trend_of(value) == expected


@pytest.mark.parametrize(
    "value",
    [Decimal("0.004"), Decimal("-0.004")],
    ids=["rounds_down_to_zero", "rounds_up_to_zero"],
)
def test_a_position_that_rounds_flat_is_not_reported_as_a_move(
    value: Decimal,
) -> None:
    """The regression this guards: a red arrow beside ``$0.00``.

    ``trend_of`` and ``signed_money_display`` both decide from the rounded
    figure. Asserting them together is what keeps them from drifting apart.
    """
    assert trend_of(value) == FLAT
    assert signed_money_display(value) == "$0.00"


def test_a_higher_precision_can_see_a_move_the_default_rounds_away() -> None:
    assert trend_of(Decimal("0.004")) == FLAT
    assert trend_of(Decimal("0.004"), precision=3) == UP
