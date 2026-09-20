"""``payoff`` — what a proposed order makes or loses if the price moves (GGU-38).

One module holds everything this tool is: its arguments (``payoff_order``),
its display shaping (``payoff_rows``), its run method and its ``register(...)``
call. Adding a tool edits no shared file (spec 0006 AC-7).

Every figure the model receives is a pre-formatted string from
``app.core.display``; the arithmetic is the domain's (``app.domain.payoff``),
including the dollars-to-units division the model must never do. It copies the
result and never recomputes it (ADR-E D-2, ADR-K D-5).

**It emits no render intent.** The projection registry holds a waterfall and an
allocation donut; neither one draws a P/L curve over a price axis, and aiming
one of them at this answer would put a confident wrong chart under a correct
sentence. ``payoff.curve.v1`` belongs to the ticket that owns the component
(spec 0014 OD-7).
"""

from collections.abc import Mapping
from typing import Final

from app.agent.contracts import ToolContext, ToolOutcome
from app.agent.registry import register
from app.agent.tools import payoff_rows
from app.agent.tools.payoff_order import PayoffArguments
from app.domain.market import market_asset
from app.domain.payoff_pricing import payoff_curve

NAME: Final[str] = "payoff"

#: Shipped in every payload, not only in the tool description: whatever the
#: model says around the numbers, the surface can state what they are — and
#: what they are not. The domain is a spot book (spec 0014 OD-8).
DISCLOSURE: Final[str] = (
    "Illustrative linear spot payoff on the demo portfolio's simulated "
    "prices: profit or loss is (price - entry) x quantity, with no fees, no "
    "slippage, no financing and no options pricing. A sell is the mirror of "
    "the position — what the units being sold would have made — and leaves "
    "no position, so it reports no position value."
)


class PayoffTool:
    """Answer "what does this order do to me if the price moves?"."""

    name = NAME
    description = (
        "Price a proposed buy or sell of one asset across a range of future "
        "prices — the risk curve behind an order ticket. Give 'size' as a "
        "decimal string and say whether it is in 'units' or 'usd'. Returns "
        "the entry price, notional, break-even price, one point per price "
        "step, and the low, entry and high scenarios, every figure already "
        "formatted. It is an illustrative linear spot payoff: no fees, no "
        "options pricing. Copy the strings, never recompute them."
    )
    parameters: Mapping[str, object] = PayoffArguments.model_json_schema()

    async def run(
        self, arguments: Mapping[str, object], context: ToolContext
    ) -> ToolOutcome:
        """Price the proposed order and return the curve pre-formatted.

        Args:
            arguments: Raw arguments from the model; validated here.
            context: The subject and the portfolio provider.

        Returns:
            The payload the model reads, and no render intent — see the module
            docstring and spec 0014 OD-7.

        Raises:
            ValidationError: When the model sent an unknown, out-of-range or
                empty-sized order.
            SymbolNotFoundError: When the ticker is not in the curated market
                reference. Both reach the turn loop as a tool error the model
                can recover from, rather than a guessed answer.
        """
        options = PayoffArguments.model_validate(dict(arguments))
        asset = market_asset(options.symbol)
        portfolio = await context.portfolios.get(context.subject)
        entry_price = portfolio.price(asset.symbol)
        curve = payoff_curve(
            symbol=asset.symbol,
            name=asset.name,
            entry_price=entry_price,
            quantity=options.units(entry_price),
            side=options.side,
            range_pct=options.range_pct,
            steps=options.steps,
        )
        # The grid's own step decides how finely a price has to be printed for
        # two neighbouring points to stay distinguishable (spec 0014 OD-10).
        precision = payoff_rows.price_precision(curve.price_step)
        data: Mapping[str, object] = {
            "asOf": portfolio.as_of.isoformat(),
            "disclosure": DISCLOSURE,
            "order": payoff_rows.order_block(curve, precision=precision),
            "scenarios": payoff_rows.scenarios(curve, precision=precision),
            "points": [
                payoff_rows.point_row(point, precision=precision)
                for point in curve.points
            ],
        }
        return ToolOutcome(data=data)


register(PayoffTool())

__all__ = ["DISCLOSURE", "NAME", "PayoffTool"]
