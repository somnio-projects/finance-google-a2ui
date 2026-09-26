"""How far one leg of a draft can go (spec 0050).

Split from ``draft_ladder`` at the file budget, along the seam that was
already there: **what bounds a leg** is a question about cash and holdings,
while **where the stops sit** is arithmetic over that bound. The ladder asks
this module once per leg and lays its stops out between zero and the answer.
"""

from decimal import ROUND_FLOOR, Decimal

from app.domain.draft_impact import DraftImpact
from app.domain.market import market_asset
from app.domain.money import ZERO
from app.domain.payoff import Side
from app.domain.portfolio import Portfolio


def _held(portfolio: Portfolio, symbol: str) -> Decimal:
    """Return the units of ``symbol`` the portfolio holds, or zero."""
    return next(
        (row.quantity for row in portfolio.holdings() if row.symbol == symbol),
        ZERO,
    )


def _affordable(impact: DraftImpact, symbol: str) -> Decimal:
    """Return what the cash affords for ``symbol`` once the others are paid for."""
    leg = next(item for item in impact.legs if item.symbol == symbol)
    headroom = impact.cash_available - (impact.total - leg.notional)
    if headroom <= ZERO:
        return ZERO
    step = market_asset(symbol).step
    return (headroom / leg.price / step).to_integral_value(ROUND_FLOOR) * step


def ceiling(
    portfolio: Portfolio, impact: DraftImpact, symbol: str, side: Side
) -> Decimal:
    """Return the most units of ``symbol`` this leg's track reaches.

    Two bounds, because a buy and a sell are bounded by different things: a
    **buy** is bounded by cash — what is left for this leg once the *other*
    legs are paid for, floored to the asset's own step — and a **sell** raises
    cash and is never blocked (``draft_impact``), so it is bounded by what the
    portfolio holds.

    Either way it is at least the quantity on screen, so a draft already past
    its cash still has its own value on its track rather than one it cannot
    sit on.

    Args:
        portfolio: Whose cash bounds a buy and whose holdings bound a sell.
        impact: The priced legs, the order's total and the cash available.
        symbol: The leg being bounded.
        side: Which way the order goes.

    Returns:
        The ceiling in units, never below the leg's current quantity.
    """
    drafted = next(item.quantity for item in impact.legs if item.symbol == symbol)
    reach = _held(portfolio, symbol) if side == "sell" else _affordable(impact, symbol)
    return max(reach, drafted)


__all__ = ["ceiling"]
