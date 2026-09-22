"""``get_holdings_summary`` — the portfolio surface every flow starts from.

Still the thinnest useful read over the portfolio domain: no new finance logic,
every figure derived from the aggregate ``app.domain`` already stores, and
every number leaving as a pre-formatted string (ADR-E D-2/D-3, ADR-K D-5). The
model copies those strings; the ranking and the ratios happen here and in
``app.domain.returns``, over exact ``Decimal`` values.

Spec 0011 added what the demo surface needs on top of spec 0006's reference
tool: a symbol filter, four orderings and a ``totals`` block. The module is
three files under the line budget — ``holdings_query`` picks the positions,
``holdings_rows`` shapes them, and this one is the tool.
"""

from collections.abc import Mapping
from typing import Final

from app.agent.contracts import RenderIntent, ToolContext, ToolOutcome
from app.agent.registry import register
from app.agent.tools import holdings_rows
from app.agent.tools.holdings_query import PARAMETERS, HoldingsSummaryArguments

VIEW: Final[str] = "holdings.allocation.v1"


class HoldingsSummaryTool:
    """Summarise the caller's positions, in the order they asked for."""

    name = "get_holdings_summary"
    description = (
        "Return the user's portfolio positions — symbol, quantity, price, "
        "market value, cost basis, unrealized profit or loss in dollars and as "
        "a percentage of cost, and weight — every figure already formatted, "
        "plus the portfolio totals. Use it for what the user holds, what it is "
        "worth, how it is allocated, or which positions are up or down. Sort "
        "by 'gainers' or 'losers' for best and worst performers. A position "
        "with no cost basis has no percentage return; give its dollar figure."
    )
    parameters = PARAMETERS

    async def run(
        self, arguments: Mapping[str, object], context: ToolContext
    ) -> ToolOutcome:
        """Return the requested positions and the portfolio totals.

        Args:
            arguments: Raw arguments from the model; validated here.
            context: The subject and the portfolio provider.

        Returns:
            The payload the model reads. The allocation render intent comes
            with it only for an unfiltered call, because that chart renders the
            whole portfolio and would contradict a filtered answer
            (spec 0011 OD-1).

        Raises:
            ValidationError: When the model sent an unknown or out-of-range
                argument. The turn loop turns that into a tool error the model
                can recover from.
        """
        options = HoldingsSummaryArguments.model_validate(dict(arguments))
        portfolio = await context.portfolios.get(context.owner)
        every = portfolio.holdings()
        shown = options.select(every)
        data: Mapping[str, object] = {
            "asOf": portfolio.as_of.isoformat(),
            "totals": holdings_rows.totals(
                count=len(every),
                market_value=portfolio.total_market_value(),
                cost_basis=portfolio.total_cost_basis(),
                unrealized_pl=portfolio.total_unrealized_pl(),
            ),
            "holdings": [holdings_rows.row(holding) for holding in shown],
        }
        chart = options.chart_options(len(shown))
        render = None if chart is None else RenderIntent(view=VIEW, options=chart)
        return ToolOutcome(data=data, render=render)


register(HoldingsSummaryTool())

__all__ = ["VIEW", "HoldingsSummaryTool"]
