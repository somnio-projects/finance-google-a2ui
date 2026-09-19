"""Spec 0014 — sizing an order in dollars.

Its own file because ``app.domain.orders`` is its own module: the division
that turns a dollar amount into units is asked for wherever an order is
described in money, and the payoff curve is only the first caller.
"""

from decimal import Decimal

from app.domain.orders import order_quantity

ENTRY = Decimal("152.40")


def test_a_dollar_amount_buys_exactly_what_it_pays_for() -> None:
    """AC-4 — the division the model must never do, done here."""
    assert order_quantity(Decimal(500), Decimal(100)) == Decimal(5)


def test_the_units_a_dollar_amount_buys_are_worth_that_amount_again() -> None:
    """AC-4 — a price that does not divide evenly leaves a remainder.

    Exact to the cent the reader is shown, not exact to the last digit: the
    quotient is unrounded on purpose, so the product comes back a
    vanishing fraction short and the **displayed** notional is what closes.
    """
    units = order_quantity(Decimal(500), ENTRY)

    assert units * ENTRY != Decimal(500)
    assert abs(units * ENTRY - Decimal(500)) < Decimal("0.00000001")
