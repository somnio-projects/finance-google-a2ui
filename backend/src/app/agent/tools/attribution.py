"""``compute_attribution`` — what moved the portfolio over a window (GGU-36).

One module holds everything this tool is: its arguments, its description, its
run method and its ``register(...)`` call. Adding a tool edits no shared file
(spec 0006 AC-7).

Every figure the model receives is a pre-formatted string from
``app.core.display``; the arithmetic is the domain's
(``app.domain.attribution``) and the model copies the result. It never rounds,
never formats and never re-derives a number (ADR-E D-2, spec 0006 AC-8).
"""

from collections.abc import Mapping
from datetime import timedelta
from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.agent.contracts import RenderIntent, ToolContext, ToolOutcome
from app.agent.registry import register
from app.core.display import money_display, percentage_display
from app.core.display import signed_money_display as signed
from app.domain.attribution import WindowAttribution, attribute_window
from app.domain.symbols import Ticker

NAME: Final[str] = "compute_attribution"
VIEW: Final[str] = "attribution.waterfall.v1"
MAX_SYMBOLS: Final[int] = 20

#: The windows the model may ask for. A closed set rather than a free-form
#: duration: the model picks, it does not invent (ADR-K D-12).
WINDOWS: Final[Mapping[str, int]] = {"1d": 1, "7d": 7, "30d": 30}
DEFAULT_WINDOW: Final[str] = "7d"


class AttributionArguments(BaseModel):
    """Declared arguments of ``compute_attribution``; nothing else is accepted."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    window: Literal["1d", "7d", "30d"] = Field(
        default=DEFAULT_WINDOW,
        description="How far back to attribute the move.",
        examples=["7d"],
    )
    symbols: tuple[Ticker, ...] | None = Field(
        default=None,
        max_length=MAX_SYMBOLS,
        description=(
            "Restrict the answer to these tickers. Omit for the whole "
            "portfolio. The totals then cover only the named holdings, so the "
            "waterfall still closes against its own total."
        ),
        examples=[["BTC", "ETH"]],
    )


def _rows(result: WindowAttribution) -> list[Mapping[str, object]]:
    """Render each contribution as display strings, biggest mover first."""
    return [
        {
            "symbol": row.symbol,
            "name": row.name,
            "startValueDisplay": money_display(row.start_value),
            "endValueDisplay": money_display(row.end_value),
            "contributionDisplay": signed(row.contribution),
            "shareDisplay": percentage_display(row.share),
            "trend": "up" if row.contribution >= 0 else "down",
        }
        for row in result.contributions
    ]


class ComputeAttributionTool:
    """Answer "why did my portfolio move, and what drove it?"."""

    @property
    def name(self) -> str:
        """Stable identifier the model calls."""
        return NAME

    @property
    def description(self) -> str:
        """What the tool answers, written for the model to choose by."""
        return (
            "Explain why the portfolio's value changed over a recent window "
            "and which holdings drove it. Returns the portfolio's start and "
            "end value, the change, and one contribution per holding, largest "
            "mover first. Use it for any 'why did it move', 'what drove it' "
            "or 'how did I do this week' question. Every value is already "
            "formatted for display — copy the strings, never recompute them."
        )

    @property
    def parameters(self) -> Mapping[str, object]:
        """JSON Schema of the accepted arguments."""
        return AttributionArguments.model_json_schema()

    async def run(
        self, arguments: Mapping[str, object], context: ToolContext
    ) -> ToolOutcome:
        """Attribute the portfolio's move and return it pre-formatted.

        Args:
            arguments: Raw arguments from the model; validated here.
            context: The subject and the portfolio provider.

        Returns:
            The payload the model reads, plus a waterfall render intent.

        Raises:
            ValidationError: When the model sent an unknown or out-of-range
                argument. The turn loop turns that into a tool error the model
                can recover from, rather than failing the turn.
        """
        options = AttributionArguments.model_validate(dict(arguments))
        portfolio = context.portfolios.get(context.subject)
        result = attribute_window(
            portfolio,
            window=timedelta(days=WINDOWS[options.window]),
            symbols=frozenset(options.symbols) if options.symbols else None,
        )
        data: Mapping[str, object] = {
            "asOf": portfolio.as_of.isoformat(),
            "window": options.window,
            "startValueDisplay": money_display(result.start_value),
            "endValueDisplay": money_display(result.end_value),
            "changeDisplay": signed(result.change),
            "changePctDisplay": percentage_display(result.change_ratio),
            "trend": "up" if result.change >= 0 else "down",
            "contributions": _rows(result),
        }
        return ToolOutcome(data=data, render=RenderIntent(view=VIEW))


register(ComputeAttributionTool())

__all__ = ["DEFAULT_WINDOW", "NAME", "VIEW", "WINDOWS", "AttributionArguments"]
