"""Return on cost — the one ratio the holdings surface needs (spec 0011 §2).

It lives in the domain rather than in the tool because it is a **financial
statement about a position**, not a way of printing one: "up 17.27 %" is an
answer, and an answer belongs where the other answers are. The tool copies it;
the model never divides (ADR-K D-5).

Deliberately not a method on ``Holding``: the same ratio applies to a single
position, to a filtered set and to the whole portfolio, and a free function
takes the two figures it needs from any of them.
"""

from decimal import Decimal

from app.domain.money import ZERO


def return_on_cost(unrealized_pl: Decimal, cost_basis: Decimal) -> Decimal | None:
    """Return the profit or loss as a ``0..1`` ratio of what was paid.

    Args:
        unrealized_pl: ``market_value - cost_basis``, negative for a loser.
        cost_basis: What the position cost; never negative.

    Returns:
        The ratio — ``0.1727`` for a position up 17.27 % — or ``None`` when
        the cost basis is zero. A return on nothing is undefined, and
        reporting it as ``0`` would call an infinitely profitable position
        flat (spec 0011 OD-2). The caller decides how to say "no answer";
        this function does not invent one.
    """
    if cost_basis == ZERO:
        return None
    return unrealized_pl / cost_basis


__all__ = ["return_on_cost"]
