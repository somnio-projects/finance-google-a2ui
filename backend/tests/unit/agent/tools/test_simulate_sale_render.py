"""Spec 0015 AC-13 — the render intent ``simulate_sale`` emits.

The tool spells the view id as a plain string, because ``app.agent`` may not
import ``app.presentation``. That makes the id **and its options** two
declarations of one fact, which is the exact shape of the three holes this
repo's testing rule records: an advertised bound and an enforced bound that
nothing compared.

So none of these tests compares the intent to a literal it wrote itself. They
resolve it through the **real registry**, validate the options with the
**projection's own model**, and render it — and the last one asserts the table
and the sentence under it name the same lots and the same result.
"""

from app.agent.contracts import ToolContext
from app.agent.tools.simulate_sale import VIEW, SimulateSaleTool
from app.presentation.registry import REGISTRY
from app.presentation.resolve import validated_options
from app.presentation.taxlot_scenario import TaxLotsTableOptions
from app.presentation.taxlots import TaxLotsTablePayload
from tests.unit.agent.tools.sale_fixtures import (
    HALF_A_BITCOIN,
    TEN_THOUSAND_DOLLARS,
    block,
    lots,
)
from tests.unit.agent.tools.sale_fixtures import tool as tool

__all__ = ["tool"]


async def test_a_successful_simulation_asks_for_the_tax_lot_table(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """The scenario named is the one that was costed, not the one asked for."""
    outcome = await tool.run(HALF_A_BITCOIN, tool_context)

    assert outcome.render is not None
    assert outcome.render.view == VIEW
    assert dict(outcome.render.options) == {
        "symbol": "NVDA",
        "quantity": "75",
        "lot_method": "FIFO",
    }


async def test_the_intent_names_a_projection_the_registry_really_holds(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """The tool's `VIEW` string and the view's `Literal` are compared here.

    `REGISTRY.get` raises `UnknownViewError` for an id nobody registered, so
    a renamed projection fails this test instead of failing a demo.
    """
    outcome = await tool.run(HALF_A_BITCOIN, tool_context)

    assert outcome.render is not None
    assert REGISTRY.get(outcome.render.view).id == VIEW


async def test_the_intents_options_validate_against_the_projections_own_model(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """An option the view does not declare would be a 422, not a render."""
    outcome = await tool.run({**HALF_A_BITCOIN, "lot_method": "HIFO"}, tool_context)

    assert outcome.render is not None
    projection = REGISTRY.get(outcome.render.view)
    options = validated_options(projection, outcome.render.options)

    assert isinstance(options, TaxLotsTableOptions)
    assert (options.symbol, options.quantity, options.lot_method) == (
        "NVDA",
        "75",
        "HIFO",
    )


async def test_the_rendered_table_names_what_the_answer_names(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """The chart and the sentence under it must not disagree.

    HIFO, because it consumes different lots than the default: a render
    intent that dropped `lot_method` would still render a plausible table,
    and only this comparison would notice.
    """
    portfolio = await tool_context.portfolios.get(tool_context.subject)
    outcome = await tool.run({**HALF_A_BITCOIN, "lot_method": "HIFO"}, tool_context)

    assert outcome.render is not None
    projection = REGISTRY.get(outcome.render.view)
    payload = projection.render(
        portfolio, validated_options(projection, outcome.render.options)
    )

    assert isinstance(payload, TaxLotsTablePayload)
    summary = block(outcome.data["summary"])
    assert payload.realized.amount.display == summary["realizedPlDisplay"]
    assert payload.subtitle == "Sell 75 NVDA under HIFO"
    assert [row.label for row in payload.lots] == [
        row["lotId"] for row in lots(outcome.data["lots"])
    ]


async def test_a_dollar_sized_ask_travels_as_the_units_it_resolved_to(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """The model never divides: the tool resolved the size, the view gets units.

    `$10,000` of NVDA is 8.30109741 shares — eight decimal places, which is
    the case `str(Decimal)` would have rendered in scientific notation for a
    small enough size and the view's size pattern would then have rejected.
    """
    outcome = await tool.run(TEN_THOUSAND_DOLLARS, tool_context)

    assert outcome.render is not None
    projection = REGISTRY.get(outcome.render.view)
    options = validated_options(projection, outcome.render.options)

    assert isinstance(options, TaxLotsTableOptions)
    assert options.quantity == block(outcome.data["summary"])["quantityDisplay"]

    portfolio = await tool_context.portfolios.get(tool_context.subject)
    payload = projection.render(portfolio, options)

    assert isinstance(payload, TaxLotsTablePayload)
    assert payload.subtitle == "Sell 8.30109741 NVDA under FIFO"
