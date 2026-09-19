"""Spec 0014 — the display decisions the payoff payload rests on.

Two of them cannot be reached through the tool: the row of an order with no
size, which the tool rejects, and the precision of a grid finer than any price
in this domain. Both are tested here directly, the same way spec 0011 tests a
zero-cost holding the seed does not contain.
"""

from decimal import Decimal

import pytest

from app.agent.tools import payoff_rows
from app.core.display import MONEY_PRECISION
from app.domain.money import ZERO
from app.domain.payoff import PayoffPoint


def test_a_point_with_no_defined_return_says_nothing_rather_than_zero() -> None:
    """OD-4 — ``null``, because ``0.00%`` would call it flat (spec 0011 OD-2)."""
    point = PayoffPoint(
        price=Decimal("152.40"),
        move_ratio=ZERO,
        position_value=ZERO,
        profit_loss=ZERO,
        return_ratio=None,
    )

    row = payoff_rows.point_row(point, precision=MONEY_PRECISION)

    assert row["returnPctDisplay"] is None
    assert row["positionValueDisplay"] == "$0.00"
    assert row["profitLossDisplay"] == "$0.00"
    assert row["trend"] == "flat"


@pytest.mark.parametrize(
    ("step", "expected"),
    [
        (Decimal("3.81"), 2),
        (Decimal("0.01"), 2),
        (Decimal("0.0099"), 3),
        (Decimal("0.00025460"), 4),
        (Decimal("0.000000001"), 8),
    ],
    ids=[
        "a_dollar_ladder_stays_at_cents",
        "a_step_of_exactly_one_cent",
        "just_under_a_cent_needs_a_third",
        "a_sub_dollar_ladder_needs_four",
        "finer_than_the_domain_can_express_is_capped",
    ],
)
def test_the_price_precision_is_the_one_that_keeps_two_points_apart(
    step: Decimal, expected: int
) -> None:
    """OD-10 — the rule that replaced a ladder printing one price per six rows."""
    assert payoff_rows.price_precision(step) == expected
