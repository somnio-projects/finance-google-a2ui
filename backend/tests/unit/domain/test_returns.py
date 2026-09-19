"""Spec 0011 — return on cost, including the case that has no answer."""

from decimal import Decimal

import pytest

from app.domain.returns import return_on_cost


@pytest.mark.parametrize(
    ("unrealized_pl", "cost_basis", "expected"),
    [
        (Decimal("266"), Decimal("1540"), Decimal("266") / Decimal("1540")),
        (Decimal("-300"), Decimal("1200"), Decimal("-0.25")),
        (Decimal(0), Decimal("1200"), Decimal(0)),
    ],
    ids=["gain", "loss", "flat"],
)
def test_return_on_cost_divides_the_profit_by_what_was_paid(
    unrealized_pl: Decimal, cost_basis: Decimal, expected: Decimal
) -> None:
    assert return_on_cost(unrealized_pl, cost_basis) == expected


def test_return_on_a_zero_cost_basis_has_no_answer_rather_than_zero() -> None:
    """Spec 0011 OD-2 — an airdrop is not a flat position."""
    assert return_on_cost(Decimal("500"), Decimal(0)) is None
