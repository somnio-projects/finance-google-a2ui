"""``driver_detail`` — what one holding did to the portfolio today (spec 0032).

The turn a tapped waterfall bar opens asks the model to *break down the
contribution of NVDA*; until this tool existed the model had nothing to
render for it and answered in prose. It now renders ``attribution.driver.v1``
for the symbol, and narrates from the strings below.

Same shape as ``compute_attribution``: one module, its arguments, its
description, ``run`` and ``register(...)``. Every figure is pre-formatted
through ``app.core.display`` and ``app.core.signed_display``; the arithmetic
is ``app.domain.driver``'s, the same function the projection renders from, so
what the model says and what the card shows are one computation.
"""

from collections.abc import Mapping
from typing import Final

from pydantic import BaseModel, ConfigDict, Field

from app.agent.contracts import RenderIntent, ToolContext, ToolOutcome
from app.agent.registry import register
from app.core.display import percentage_display, price_display, quantity_display
from app.core.signed_display import signed_money_display, signed_percentage_display
from app.domain.day_change import trend_of
from app.domain.driver import DriverDetail, driver_detail
from app.domain.symbols import Ticker, normalize_symbol

NAME: Final[str] = "driver_detail"
VIEW: Final[str] = "attribution.driver.v1"


class DriverDetailArguments(BaseModel):
    """Declared arguments of ``driver_detail``; nothing else is accepted."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    symbol: Ticker = Field(
        description="The holding to describe — the bar that was tapped.",
        examples=["NVDA"],
    )


def _figures(detail: DriverDetail) -> Mapping[str, object]:
    """Render one detail as the strings the model copies."""
    return {
        "symbol": detail.symbol,
        "name": detail.name,
        "standing": detail.standing,
        "rank": detail.rank,
        "contributionDisplay": signed_money_display(detail.contribution),
        "priceMovePctDisplay": signed_percentage_display(detail.price_ratio),
        "priceMoveDisplay": signed_money_display(detail.price_change),
        "sharesDisplay": quantity_display(detail.quantity, trim=True),
        "priceDisplay": price_display(detail.price),
        "shareOfDayDisplay": percentage_display(detail.share),
        "dayGainDisplay": signed_money_display(detail.day_gain),
        "trend": trend_of(detail.contribution),
    }


class DriverDetailTool:
    """Answer "what did this holding do today?" for one tapped bar."""

    @property
    def name(self) -> str:
        """Stable identifier the model calls."""
        return NAME

    @property
    def description(self) -> str:
        """What the tool answers, written for the model to choose by."""
        return (
            "Break down one holding's part in today's move: its contribution, "
            "how far its price moved, how many units carried it and what share "
            "of the day's result it was. Use it when the user asks about one "
            "driver, one bar of the attribution chart or one ticker's move "
            "today. Every value is already formatted for display — copy the "
            "strings, never recompute them. `standing` and `rank` place it "
            "among today's movers; when `held` is false there is nothing to "
            "break down, say so."
        )

    @property
    def parameters(self) -> Mapping[str, object]:
        """JSON Schema of the accepted arguments."""
        return DriverDetailArguments.model_json_schema()

    async def run(
        self, arguments: Mapping[str, object], context: ToolContext
    ) -> ToolOutcome:
        """Describe the symbol's day and ask for its card.

        Args:
            arguments: Raw arguments from the model; validated here.
            context: The subject and the portfolio provider.

        Returns:
            The figures the model reads plus the card's render intent — or,
            for a symbol the portfolio does not hold, ``held: false`` and no
            render: the leaf a drill can reach, answered rather than failed.

        Raises:
            ValidationError: When the model sent an unknown or malformed
                argument; the turn loop turns that into a recoverable error.
        """
        options = DriverDetailArguments.model_validate(dict(arguments))
        symbol = normalize_symbol(options.symbol)
        portfolio = await context.portfolios.get(context.subject)
        detail = driver_detail(portfolio, symbol)
        if detail is None:
            return ToolOutcome(data={"symbol": symbol, "held": False})
        return ToolOutcome(
            data={
                "held": True,
                "asOf": portfolio.as_of.isoformat(),
                **_figures(detail),
            },
            render=RenderIntent(view=VIEW, options={"symbol": detail.symbol}),
        )


register(DriverDetailTool())

__all__ = ["NAME", "VIEW", "DriverDetailArguments", "DriverDetailTool"]
