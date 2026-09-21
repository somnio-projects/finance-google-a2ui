"""Spec 0013 OD-6 — the one return-on-cost string both tools report."""

from decimal import Decimal

import pytest

from app.agent.tools.ratios import return_display


@pytest.mark.parametrize(
    ("profit", "cost_basis", "expected"),
    [
        ("2660.00", "15400.00", "17.27%"),
        ("-1248.75", "9200.00", "-13.57%"),
        ("0", "9200.00", "0.00%"),
    ],
    ids=["a_gain_reads_positive", "a_loss_reads_negative", "flat_reads_zero"],
)
def test_a_profit_reads_as_a_share_of_what_was_paid(
    profit: str, cost_basis: str, expected: str
) -> None:
    """The percentage the model copies, signed and already rounded."""
    assert return_display(Decimal(profit), Decimal(cost_basis)) == expected


def test_a_return_on_nothing_is_absent_rather_than_zero() -> None:
    """OD-6 — ``"0.00%"`` would call an infinitely profitable position flat."""
    assert return_display(Decimal(500), Decimal(0)) is None
