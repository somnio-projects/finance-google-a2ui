"""``get_holdings_summary`` — the reference tool that proves the seam.

It is deliberately the thinnest useful read over the portfolio domain: no new
finance logic, every figure already computed by ``app.domain`` and every
number leaving as a pre-formatted ``*Display`` string (ADR-E D-2/D-3, ADR-K
D-5). The model copies those strings; the arithmetic — the totals and the
ordering — happens here, in Python, over exact ``Decimal`` values.

Adding the next tool (GGU-36/37/38/39) means copying this module's shape: a
pydantic arguments model, a ``run`` over the injected context, and one
``register(...)`` line. No shared file changes.
"""

from collections.abc import Mapping
from decimal import Decimal
from typing import Final

from pydantic import BaseModel, ConfigDict, Field

from app.agent.contracts import RenderIntent, ToolContext, ToolOutcome
from app.agent.registry import register
from app.core.display import money_display, percentage_display, quantity_display
from app.core.display import signed_money_display as signed
from app.domain.holdings import Holding

MAX_TOP_N: Final[int] = 20
VIEW: Final[str] = "holdings.allocation.v1"

_PARAMETERS: Final[Mapping[str, object]] = {
    "type": "object",
    "properties": {
        "top_n": {
            "type": "integer",
            "minimum": 1,
            "maximum": MAX_TOP_N,
            "description": "Keep only the N largest positions by market value.",
        }
    },
    "required": [],
    "additionalProperties": False,
}


class HoldingsSummaryArguments(BaseModel):
    """Validated arguments; anything undeclared is rejected (spec 0006 §5)."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    top_n: int | None = Field(
        default=None, ge=1, le=MAX_TOP_N, description="How many positions to keep."
    )


def _row(holding: Holding) -> Mapping[str, object]:
    """Render one holding as display strings only."""
    return {
        "symbol": holding.symbol,
        "name": holding.name,
        "quantityDisplay": quantity_display(holding.quantity, trim=True),
        "priceDisplay": money_display(holding.price),
        "marketValueDisplay": money_display(holding.market_value),
        "costBasisDisplay": money_display(holding.cost_basis),
        "unrealizedPlDisplay": signed(holding.unrealized_pl),
        "weightDisplay": percentage_display(holding.weight),
    }


class HoldingsSummaryTool:
    """Summarise the caller's positions, largest first."""

    name = "get_holdings_summary"
    description = (
        "Return the user's current portfolio positions — symbol, quantity, "
        "price, market value, cost basis, unrealized profit or loss and "
        "weight — largest position first, with every figure already formatted "
        "for display. Use it for any question about what the user holds, how "
        "much it is worth, or how the portfolio is allocated."
    )
    parameters = _PARAMETERS

    async def run(
        self, arguments: Mapping[str, object], context: ToolContext
    ) -> ToolOutcome:
        """Return the positions and the portfolio totals.

        Args:
            arguments: Raw arguments from the model; validated here.
            context: The subject and the portfolio provider.

        Returns:
            The payload the model reads, plus the allocation render intent.

        Raises:
            ValidationError: When the model sent an unknown or out-of-range
                argument. The turn loop turns that into a tool error the model
                can recover from.
        """
        options = HoldingsSummaryArguments.model_validate(dict(arguments))
        portfolio = context.portfolios.get(context.subject)
        ranked = sorted(
            portfolio.holdings(), key=lambda item: item.market_value, reverse=True
        )
        shown = ranked[: options.top_n] if options.top_n is not None else ranked
        total = sum((item.market_value for item in ranked), Decimal(0))
        unrealized = sum((item.unrealized_pl for item in ranked), Decimal(0))
        data: Mapping[str, object] = {
            "asOf": portfolio.as_of.isoformat(),
            "positionCount": len(ranked),
            "totalMarketValueDisplay": money_display(total),
            "totalUnrealizedPlDisplay": signed(unrealized),
            "holdings": [_row(holding) for holding in shown],
        }
        return ToolOutcome(
            data=data,
            render=RenderIntent(view=VIEW, options={"top_n": len(shown)}),
        )


register(HoldingsSummaryTool())

__all__ = ["MAX_TOP_N", "VIEW", "HoldingsSummaryArguments", "HoldingsSummaryTool"]
