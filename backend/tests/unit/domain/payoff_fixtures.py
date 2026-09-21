"""Shared helpers for the payoff domain tests.

Not a test module: it holds the curve builder that ``test_payoff`` (the shape
of the grid) and ``test_payoff_figures`` (the figures at each point) both
need, so neither file repeats it.
"""

from decimal import Decimal

from app.domain.payoff import PayoffCurve, Side
from app.domain.payoff_pricing import payoff_curve

ENTRY = Decimal("528.00")
QUANTITY = Decimal("40")
RANGE_PCT = 30
STEPS = 12


def build(
    *,
    side: Side = "buy",
    quantity: Decimal = QUANTITY,
    range_pct: int = RANGE_PCT,
    steps: int = STEPS,
) -> PayoffCurve:
    """Return a curve over the seeded VOO price, varying one thing at a time."""
    return payoff_curve(
        symbol="VOO",
        name="Vanguard S&P 500 ETF",
        entry_price=ENTRY,
        quantity=quantity,
        side=side,
        range_pct=range_pct,
        steps=steps,
    )


__all__ = ["ENTRY", "QUANTITY", "RANGE_PCT", "STEPS", "build"]
