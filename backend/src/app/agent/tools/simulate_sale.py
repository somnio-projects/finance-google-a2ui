"""``simulate_sale`` — what a sell would realise, lot by lot (GGU-37).

The deterministic tool behind Flow B's tax-lot comparator. The finance is
``app.domain.sales``; this module validates what was asked for, calls it once,
and hands the model pre-formatted strings (ADR-E D-2, ADR-K D-5). The model
copies them: it never multiplies a quantity by a price, never subtracts a cost
basis and never decides whether a lot is short- or long-term.

It emits a render intent for ``taxlots.table.v1`` (spec 0015), which is the
projection OD-5 refused to invent before the component existed. Only on a
**successful** simulation: a ``position-too-small`` refusal has no table to
draw, and a chart that contradicts the sentence under it is the failure spec
0011 OD-1 named.

Registration is the module's own last line, so adding this tool edited no
shared file (spec 0006 AC-7).
"""

from collections.abc import Mapping
from typing import Final

from app.agent.contracts import RenderIntent, ToolContext, ToolOutcome
from app.agent.registry import register
from app.agent.tools import sale_rows
from app.agent.tools.sale_request import SimulateSaleArguments
from app.domain.errors import PositionTooSmallError
from app.domain.sales import simulate_sale

NAME: Final[str] = "simulate_sale"
#: The projection this answer is drawn with (spec 0015). Spelled here, as
#: every tool spells its view: ``app.agent`` does not import
#: ``app.presentation``, and a test resolves this id through the real registry
#: so the two declarations cannot drift apart.
VIEW: Final[str] = "taxlots.table.v1"


class SimulateSaleTool:
    """Answer "what happens if I sell this, and which lots does it cost me?"."""

    @property
    def name(self) -> str:
        """Stable identifier the model calls."""
        return NAME

    @property
    def description(self) -> str:
        """What the tool answers, written for the model to choose by."""
        return (
            "Cost a what-if sale of one holding: which tax lots it consumes "
            "under FIFO, LIFO or HIFO, the proceeds, the cost basis, the "
            "realized gain or loss split short-term vs long-term, and the "
            "position left over. Nothing is traded. Give the size as a "
            "decimal string, in units (quantity) or dollars (amount_usd), never "
            "both. 'position-too-small' means the user holds fewer units than "
            "that — say so, quoting heldDisplay. Every figure is already "
            "formatted: copy the strings, never recompute them, never apply a "
            "tax rate."
        )

    @property
    def parameters(self) -> Mapping[str, object]:
        """JSON Schema of the accepted arguments."""
        return SimulateSaleArguments.model_json_schema()

    async def run(
        self, arguments: Mapping[str, object], context: ToolContext
    ) -> ToolOutcome:
        """Cost the proposed sale and return it pre-formatted.

        Args:
            arguments: Raw arguments from the model; validated here.
            context: The subject and the portfolio provider.

        Returns:
            The payload the model reads, plus a ``taxlots.table.v1`` render
            intent naming the sale that was actually costed. An over-sell
            comes back as a structured ``position-too-small`` answer carrying
            both quantities formatted — and **no** render intent, because
            there are no lots to draw — rather than as a raising tool the loop
            would flatten to ``tool-failed``; the shortfall is the useful
            part, and the model must copy it rather than invent it (OD-3).

        Raises:
            ValidationError: When the model sent an unknown or out-of-range
                argument. The turn loop turns that into a tool error the model
                can recover from, rather than failing the turn.
        """
        options = SimulateSaleArguments.model_validate(dict(arguments))
        portfolio = context.portfolios.get(context.subject)
        as_of = portfolio.as_of.isoformat()
        price = portfolio.price(options.symbol)
        try:
            result = simulate_sale(
                portfolio,
                symbol=options.symbol,
                quantity=options.units(price),
                method=options.method(),
            )
        except PositionTooSmallError as exc:
            refusal = sale_rows.too_small(
                symbol=exc.symbol, requested=exc.requested, held=exc.held
            )
            return ToolOutcome(data={"asOf": as_of, **refusal})
        data: Mapping[str, object] = {
            "asOf": as_of,
            "summary": sale_rows.summary(result, method=options.lot_method),
            "remaining": sale_rows.remaining(result),
            "lots": [sale_rows.lot_row(row) for row in result.consumed],
        }
        scenario = sale_rows.scenario(result, method=options.lot_method)
        return ToolOutcome(data=data, render=RenderIntent(view=VIEW, options=scenario))


register(SimulateSaleTool())

__all__ = ["NAME", "VIEW", "SimulateSaleTool"]
