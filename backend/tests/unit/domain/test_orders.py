"""Spec 0014 — sizing an order in dollars.

Its own file because ``app.domain.orders`` is its own module: the division
that turns a dollar amount into units is asked for wherever an order is
described in money, and the payoff curve is only the first caller.
"""

from decimal import Decimal

from app.domain.orders import order_notional, order_quantity

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


def test_an_order_is_worth_its_units_times_the_price_it_is_struck_at() -> None:
    """Spec 0018 AC-4 — the ticket's other figure, stated by the domain."""
    assert order_notional(Decimal("0.25"), ENTRY) == Decimal("38.1000")


def test_an_order_for_no_units_is_worth_nothing_rather_than_failing() -> None:
    """Spec 0018 OD-4 — a ticket for nothing is representable, like a curve is."""
    assert order_notional(Decimal(0), ENTRY) == Decimal(0)


def test_sizing_and_pricing_an_order_close_on_each_other_to_the_cent() -> None:
    """Spec 0018 AC-4 — the two halves of the ticket must agree."""
    units = order_quantity(Decimal(500), ENTRY)

    assert round(order_notional(units, ENTRY), 2) == Decimal("500.00")
