"""Display shaping for ``get_holdings_summary`` (spec 0011 §3).

Split out of the tool module under the 150-line budget, along the one seam
that was already there: **what the answer is** (which positions, in which
order) stays with the tool; **how a position reads** lives here. Every
function is pure and returns nothing but strings, so "did a raw number
escape?" is a question about this file alone.

It registers no tool. ``load_tools()`` imports it like any other module in the
package and nothing happens, which is the intended cost of keeping a tool's
helper next to the tool instead of in a shared file (spec 0006 AC-7).
"""

from collections.abc import Mapping
from decimal import Decimal

from app.agent.tools.ratios import return_display
from app.core.display import (
    money_display,
    percentage_display,
    quantity_display,
    signed_money_display,
)
from app.core.trend import trend_of
from app.domain.holdings import Holding


def row(holding: Holding) -> Mapping[str, object]:
    """Render one position as display strings and a trend token.

    Args:
        holding: The aggregated position, straight from the domain.

    Returns:
        The row the model copies. ``unrealizedPlPctDisplay`` is ``None`` for a
        position with no cost basis (spec 0011 OD-2); every other value is a
        string.
    """
    return {
        "symbol": holding.symbol,
        "name": holding.name,
        "quantityDisplay": quantity_display(holding.quantity, trim=True),
        "priceDisplay": money_display(holding.price),
        "marketValueDisplay": money_display(holding.market_value),
        "costBasisDisplay": money_display(holding.cost_basis),
        "unrealizedPlDisplay": signed_money_display(holding.unrealized_pl),
        "unrealizedPlPctDisplay": return_display(
            holding.unrealized_pl, holding.cost_basis
        ),
        "weightDisplay": percentage_display(holding.weight),
        "trend": trend_of(holding.unrealized_pl),
    }


def totals(
    *, count: int, market_value: Decimal, cost_basis: Decimal, unrealized_pl: Decimal
) -> Mapping[str, object]:
    """Render the portfolio-wide figures.

    Args:
        count: How many positions the **portfolio** holds — not how many rows
            the call returned, which a filter or ``top_n`` may have narrowed.
        market_value: Total market value.
        cost_basis: Total cost basis.
        unrealized_pl: Total unrealised profit or loss.

    Returns:
        The totals block. ``count`` is a cardinality and ``trend`` a UI token;
        everything else is a display string.
    """
    return {
        "count": count,
        "marketValueDisplay": money_display(market_value),
        "costBasisDisplay": money_display(cost_basis),
        "unrealizedPlDisplay": signed_money_display(unrealized_pl),
        "unrealizedPlPctDisplay": return_display(unrealized_pl, cost_basis),
        "trend": trend_of(unrealized_pl),
    }


__all__ = ["row", "totals"]
