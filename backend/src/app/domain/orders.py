"""Sizing a proposed order (spec 0014).

One statement, kept apart from ``app.domain.payoff_pricing`` because it is
about the **order**, not about the curve: "how many units does this much money
buy?" is asked wherever an order is described in dollars, and the payoff curve
is only the first place that asks.

Pure: the price arrives as an argument and nothing here rounds — rounding
happens once, at display (ADR-E D-3).
"""

from decimal import ROUND_FLOOR, Decimal


def floor_to_step(units: Decimal, *, step: Decimal) -> Decimal:
    """Return ``units`` rounded **down** to a whole multiple of ``step``.

    The crypto reading of "whole shares" (spec 0044 OD-6). Flooring to one is
    what an equity order did, and it would turn a $10,000 intent in BTC into
    zero units; flooring to the asset's declared step keeps the leg buyable and
    keeps it on the grid the ticket's ``+`` and ``-`` move along.

    Args:
        units: The exact quotient a dollar amount bought.
        step: The asset's step from the market reference; positive
            (``Field(gt=0)``), so this cannot divide by zero.

    Returns:
        The largest multiple of ``step`` not exceeding ``units``. Rounding
        **down** is the whole point: a leg never spends more than was asked.
    """
    return (units / step).to_integral_value(rounding=ROUND_FLOOR) * step


def order_quantity(amount: Decimal, price: Decimal) -> Decimal:
    """Return how many units ``amount`` buys at ``price``.

    The one division the ticket insists happens server-side: the model states
    a dollar amount, this states the units, and the model copies them — it
    never divides (ADR-K D-5).

    Args:
        amount: What the order spends, in USD.
        price: The price a unit is bought or sold at; positive, as every price
            in the curated market reference is (``Field(gt=0)``).

    Returns:
        The exact quotient, unrounded. It does not multiply back to ``amount``
        exactly when the price does not divide it evenly — the **displayed**
        notional does, which is what the caller reads (spec 0014 AC-4).
    """
    return amount / price


def order_notional(quantity: Decimal, price: Decimal) -> Decimal:
    """Return what ``quantity`` units are worth at ``price``.

    The mirror of :func:`order_quantity` and the ticket's other figure: an
    order's value in USD. It lives here rather than in the presenter that
    prints it, because what an order is worth is a financial statement and a
    presenter holds no business rule (ADR-K D-6).

    Args:
        quantity: Units the order covers; zero is an order for nothing.
        price: The price a unit is bought or sold at.

    Returns:
        The exact product, unrounded — rounding happens once, at display.
    """
    return quantity * price


__all__ = ["floor_to_step", "order_notional", "order_quantity"]
