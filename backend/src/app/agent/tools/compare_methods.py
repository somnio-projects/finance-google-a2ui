"""``compare_lot_methods`` — the same sale, costed several ways (GGU-143).

The turn behind ``scenario.comparison.v1``. Until this existed the card was
registered, served, gated and measured, and **nothing drew it**: the only
place a person met it was the catalog gallery's thumbnail. A component the
product cannot show is not finished, which is the same lesson GGU-79 recorded
one layer in — *"adding a component edits no existing file" is a claim about
the whole path to the screen*.

The finance is ``app.domain.sales``, run once per method; this module
validates what was asked for and hands the model pre-formatted strings
(ADR-E D-2, ADR-K D-5). It ranks nothing and applies no tax rate — the
projection does both, and says on the card which rate it used (GGU-134).

Registration is the module's own last line, so adding this tool edited no
shared file (spec 0006 AC-7).
"""

from collections.abc import Mapping
from typing import Final

from app.agent.contracts import RenderIntent, ToolContext, ToolOutcome
from app.agent.registry import register
from app.agent.tools import compare_rows, sale_rows
from app.agent.tools.compare_request import CompareMethodsArguments
from app.domain.errors import PositionTooSmallError
from app.domain.sales import simulate_sale

NAME: Final[str] = "compare_lot_methods"
#: The projection this answer is drawn with (spec 0017). Spelled here, as
#: every tool spells its view: ``app.agent`` does not import
#: ``app.presentation``, and a test resolves this id through the real registry
#: so the two declarations cannot drift apart.
VIEW: Final[str] = "scenario.comparison.v1"


class CompareLotMethodsTool:
    """Answer "which lot-selection method leaves me better off on this sale?"."""

    @property
    def name(self) -> str:
        """Stable identifier the model calls."""
        return NAME

    @property
    def description(self) -> str:
        """What the tool answers, written for the model to choose by."""
        return (
            "Cost the SAME what-if sale under two or three lot-selection "
            "methods at once, so FIFO, LIFO and HIFO read side by side: "
            "proceeds, cost basis, realized gain or loss and the short/long "
            "split per method. Use it when the question is WHICH method; use "
            "simulate_sale when one is chosen. Nothing is traded. Size is a "
            "decimal string, in units (quantity) or dollars (amount_usd), "
            "never both. 'position-too-small' means fewer units are held; "
            "quote heldDisplay. Copy every figure; the card ranks the columns."
        )

    @property
    def parameters(self) -> Mapping[str, object]:
        """JSON Schema of the accepted arguments."""
        return CompareMethodsArguments.model_json_schema()

    async def run(
        self, arguments: Mapping[str, object], context: ToolContext
    ) -> ToolOutcome:
        """Cost the proposed sale under each requested method.

        Args:
            arguments: Raw arguments from the model; validated here.
            context: The subject and the portfolio provider.

        Returns:
            One column per method plus the sale they share, and a
            ``scenario.comparison.v1`` render intent naming the comparison
            that was actually costed. An over-sell comes back as the same
            structured ``position-too-small`` answer ``simulate_sale``
            returns — and **no** render intent: it fails every column
            identically, so there is no card to draw (spec 0017 OD-5), and
            the shortfall is the useful part.

        Raises:
            ValidationError: When the model sent an unknown or out-of-range
                argument. The turn loop turns that into a tool error the model
                can recover from, rather than failing the turn.
        """
        options = CompareMethodsArguments.model_validate(dict(arguments))
        portfolio = await context.portfolios.get(context.owner)
        as_of = portfolio.as_of.isoformat()
        price = portfolio.price(options.symbol)
        units = options.units(price)
        try:
            runs = [
                simulate_sale(
                    portfolio, symbol=options.symbol, quantity=units, method=method
                )
                for method in options.selections()
            ]
        except PositionTooSmallError as exc:
            refusal = sale_rows.too_small(
                symbol=exc.symbol, requested=exc.requested, held=exc.held
            )
            return ToolOutcome(data={"asOf": as_of, **refusal})
        data: Mapping[str, object] = {
            "asOf": as_of,
            "subject": compare_rows.subject(runs[0], methods=options.methods),
            "columns": [
                sale_rows.summary(run, method=method)
                for run, method in zip(runs, options.methods, strict=True)
            ],
        }
        return ToolOutcome(
            data=data,
            render=RenderIntent(
                view=VIEW,
                options=compare_rows.render_options(
                    runs[0],
                    methods=options.methods,
                    include_wait=options.include_wait,
                ),
            ),
        )


register(CompareLotMethodsTool())

__all__ = ["NAME", "VIEW", "CompareLotMethodsTool"]
