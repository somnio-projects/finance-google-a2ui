"""Spec 0014 — the one payoff row the tool can never produce.

``payoff`` rejects an order of zero size, so the undefined-return branch is
unreachable through the tool and is tested here against a hand-built point —
the same way spec 0011 tests a zero-cost holding the seed does not contain.
"""

from decimal import Decimal

from app.agent.tools import payoff_rows
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

    row = payoff_rows.point_row(point)

    assert row["returnPctDisplay"] is None
    assert row["profitLossDisplay"] == "$0.00"
    assert row["trend"] == "flat"
