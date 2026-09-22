"""``draft_order`` — a vague buying intent as an editable multi-leg draft (spec 0031).

*"Put about $10k into semiconductors, keep it diversified."* The model names a
basket and an amount; **this** picks the legs, weighs them and divides dollars
by prices (``app.domain.baskets``), then states what the draft costs and
shifts (``app.domain.draft_impact``, ``draft_weights``). Every figure leaves as
a pre-formatted string the model copies (ADR-E D-2, ADR-K D-5); the render
intent hands the client ``order.ticket.v2`` with the ``legs`` option the same
composition produced, so the words and the surface describe one order.

One module holds the arguments, the run and the ``register(...)`` call —
adding a tool edits no shared file (spec 0006 AC-7). ``draft_order_rows``
beside it turns the domain's statements into strings.
"""

from collections.abc import Mapping
from decimal import Decimal
from typing import Final, Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.agent.contracts import RenderIntent, ToolContext, ToolOutcome
from app.agent.registry import register
from app.agent.tools import draft_order_rows as rows
from app.domain.baskets import Basket, basket_legs
from app.domain.draft_impact import draft_impact
from app.domain.draft_legs import format_legs
from app.domain.draft_weights import weight_shifts
from app.domain.money import ZERO
from app.domain.payoff import Side

NAME: Final[str] = "draft_order"
#: The projection the intent renders. A literal here, not an import: the agent
#: package may reach ``core`` and ``domain`` only, and the registry judges the
#: id when the intent is resolved (ADR-K D-11/D-12).
VIEW: Final[str] = "order.ticket.v2"
#: Twelve integer digits and cents, no sign, no separators — a plain amount.
AMOUNT_PATTERN: Final[str] = r"^\d{1,12}(\.\d{1,2})?$"
MAX_AMOUNT_TEXT: Final[int] = 15


class DraftOrderArguments(BaseModel):
    """Declared arguments of ``draft_order``; nothing else is accepted."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    amount: str = Field(
        pattern=AMOUNT_PATTERN,
        max_length=MAX_AMOUNT_TEXT,
        description=(
            "How much to put in, in US dollars, as a positive decimal string "
            "such as '10000'. A string, so the amount the user said is the "
            "amount that is spread."
        ),
        examples=["10000"],
    )
    basket: Basket = Field(
        description=(
            "What to buy into: 'semiconductors' (NVDA, AVGO, AMD at 40/35/25), "
            "or a sector — 'technology', 'financials', 'healthcare', "
            "'consumer', 'energy' — split equally across its single names."
        ),
        examples=["semiconductors"],
    )
    side: Side = Field(
        default="buy",
        description="'buy' spends the portfolio's cash; 'sell' raises it.",
        examples=["buy"],
    )

    @model_validator(mode="after")
    def _reject_an_empty_order(self) -> Self:
        """Return the arguments, unless they ask to spread nothing.

        Raises:
            ValueError: When the amount is zero — a draft of nothing has no
                legs worth proposing, and the model should ask again.
        """
        if Decimal(self.amount) <= ZERO:
            msg = "the amount must be greater than zero"
            raise ValueError(msg)
        return self


class DraftOrderTool:
    """Turn "put about this much into that" into legs the user can edit."""

    name = NAME
    description = (
        "Compose an editable multi-leg draft order from a vague intent: a "
        "dollar amount and a basket ('semiconductors' or a sector). Returns "
        "the legs (ticker, whole shares, price, value, weight) and the impact "
        "(total, shares, simulated fees, cash remaining, the sector's weight "
        "before and after), every figure already formatted, plus whether the "
        "available cash covers it. Nothing is placed. Copy the strings, never "
        "recompute them, and never confirm an order in prose."
    )
    parameters: Mapping[str, object] = DraftOrderArguments.model_json_schema()

    async def run(
        self, arguments: Mapping[str, object], context: ToolContext
    ) -> ToolOutcome:
        """Compose the draft and return it pre-formatted, with its surface.

        Args:
            arguments: Raw arguments from the model; validated here.
            context: The subject and the portfolio provider.

        Returns:
            The payload the model reads and the render intent for
            ``order.ticket.v2`` carrying the same ``legs`` (spec 0031 AC-7).

        Raises:
            ValidationError: When the model sent an unknown basket, an
                undeclared argument or an amount of nothing.
        """
        options = DraftOrderArguments.model_validate(dict(arguments))
        portfolio = await context.portfolios.get(context.subject)
        requests = basket_legs(options.basket, Decimal(options.amount))
        impact = draft_impact(portfolio, requests, options.side)
        shifts = weight_shifts(portfolio, impact.legs, options.side)
        legs = format_legs(requests)
        data: Mapping[str, object] = {
            "asOf": portfolio.as_of.isoformat(),
            "disclosure": rows.DISCLOSURE,
            "side": options.side,
            "legs": legs,
            "lines": [rows.line(leg) for leg in impact.legs],
            "impact": rows.impact_block(impact, shifts),
            "constraints": rows.constraints_block(impact),
        }
        render = RenderIntent(view=VIEW, options={"legs": legs, "side": options.side})
        return ToolOutcome(data=data, render=render)


register(DraftOrderTool())

__all__ = ["AMOUNT_PATTERN", "NAME", "VIEW", "DraftOrderArguments", "DraftOrderTool"]
