"""Spec 0011 OD-2 — the position the seeded portfolio does not contain.

``cost_basis`` is ``ge=0``, so a zero-cost position is representable and the
row shaping has a branch for it. The seed has no airdrop, so the branch is
reached here, with a hand-built ``Holding``, rather than left untested.
"""

from decimal import Decimal

from app.agent.tools import holdings_rows
from app.domain.holdings import Holding

AIRDROP = Holding(
    symbol="FREE",
    name="Airdropped token",
    quantity=Decimal("100"),
    price=Decimal("5"),
    market_value=Decimal("500"),
    cost_basis=Decimal(0),
    unrealized_pl=Decimal("500"),
    weight=Decimal("0.03"),
)


def test_a_position_with_no_cost_basis_reports_no_percentage_return() -> None:
    row = holdings_rows.row(AIRDROP)

    assert row["unrealizedPlPctDisplay"] is None
    assert row["unrealizedPlDisplay"] == "+$500.00"
    assert row["trend"] == "up"
    assert row["costBasisDisplay"] == "$0.00"


def test_totals_over_a_zero_cost_portfolio_report_no_percentage_return() -> None:
    block = holdings_rows.totals(
        count=1,
        market_value=Decimal("500"),
        cost_basis=Decimal(0),
        unrealized_pl=Decimal("500"),
    )

    assert block["unrealizedPlPctDisplay"] is None
    assert block["costBasisDisplay"] == "$0.00"
    assert block["count"] == 1
