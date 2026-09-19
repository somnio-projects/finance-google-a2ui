"""How a payoff curve is computed (spec 0014).

``app.domain.payoff`` says what a payoff **is**; this says how one is built —
the price grid, the profit at each point, and the single division that turns a
dollar amount into units. Pricing here means arithmetic over a spot price that
is given to it: there is no derivatives pricing model in this repository and
this module is not the beginning of one (spec 0014 OD-8).

Pure and deterministic: the entry price, the size and the grid arrive as
arguments, and nothing here reads a clock or a repository (ADR-F D-6). No
intermediate value is rounded — rounding happens once, at display
(ADR-E D-3).
"""

from decimal import Decimal
from typing import Final

from app.domain.errors import PayoffRangeError
from app.domain.money import ONE
from app.domain.payoff import MIN_STEPS, PayoffCurve, PayoffPoint, Side
from app.domain.returns import return_on_cost

#: Percent points per unit ratio — ``range_pct`` arrives as an integer percent
#: because a float ratio cannot be made exact afterwards (spec 0014 OD-3).
PERCENT: Final[Decimal] = Decimal(100)


def order_quantity(amount: Decimal, price: Decimal) -> Decimal:
    """Return how many units ``amount`` buys at ``price``.

    The one division the ticket insists happens server-side: the model states
    a dollar amount, this states the units, and the model copies them.

    Args:
        amount: What the order spends, in USD.
        price: The entry price; positive, as every price in the curated
            market reference is (``Field(gt=0)``).

    Returns:
        The exact quotient, unrounded.
    """
    return amount / price


def _point(
    *,
    entry_price: Decimal,
    quantity: Decimal,
    notional: Decimal,
    direction: Decimal,
    move_ratio: Decimal,
) -> PayoffPoint:
    """Price the order at one point of the grid."""
    price = entry_price * (ONE + move_ratio)
    profit_loss = direction * (price - entry_price) * quantity
    return PayoffPoint(
        price=price,
        move_ratio=move_ratio,
        position_value=price * quantity,
        profit_loss=profit_loss,
        return_ratio=return_on_cost(profit_loss, notional),
    )


def payoff_curve(
    *,
    symbol: str,
    name: str,
    entry_price: Decimal,
    quantity: Decimal,
    side: Side,
    range_pct: int,
    steps: int,
) -> PayoffCurve:
    """Price ``quantity`` units of ``symbol`` across ``±range_pct`` of the entry.

    The grid carries ``steps`` moves on each side of the entry, so the entry
    is a point on it rather than a value between two samples: the profit there
    is exactly zero, not approximately (spec 0014 OD-2).

    Args:
        symbol: Canonical ticker, already normalised.
        name: Display name of the asset.
        entry_price: The price the order is struck at.
        quantity: Units the order covers. Zero is representable and yields a
            flat curve with no defined return, which is what the tool's own
            rejection of an empty order is measured against.
        side: ``buy`` for the position itself, ``sell`` for its mirror — what
            the units being sold would have made (spec 0014 OD-6).
        range_pct: Half-span of the grid, as an integer percent.
        steps: Price steps **per side**; the curve is ``2 * steps + 1`` points.

    Returns:
        The curve, ascending by price.

    Raises:
        PayoffRangeError: When ``steps`` is below one. A curve needs a step on
            each side of the entry to be a curve, and the grid divides by
            ``steps`` — the same treatment ``attribute_window`` gives a
            negative window.
    """
    if steps < MIN_STEPS:
        msg = f"a payoff curve needs at least {MIN_STEPS} step per side, got {steps}"
        raise PayoffRangeError(msg)
    direction = ONE if side == "buy" else -ONE
    notional = entry_price * quantity
    span = Decimal(range_pct) / PERCENT
    return PayoffCurve(
        symbol=symbol,
        name=name,
        side=side,
        entry_price=entry_price,
        quantity=quantity,
        notional=notional,
        break_even_price=entry_price,
        points=tuple(
            _point(
                entry_price=entry_price,
                quantity=quantity,
                notional=notional,
                direction=direction,
                move_ratio=span * step / steps,
            )
            for step in range(-steps, steps + 1)
        ),
    )


__all__ = ["PERCENT", "order_quantity", "payoff_curve"]
