"""Spec 0052 — the render intent that finally draws the comparison card.

This is the suite the ticket is about. `scenario.comparison.v1` was
registered, served by the read endpoint, bound by a component, covered to
100 % and measured against the design, and **no turn drew it**. So none of
these tests compares the intent to a literal it wrote itself: they resolve it
through the **real registry**, validate the options with the **projection's
own model**, render it, and assert the card and the sentence under it name
the same sale.

The same shape `test_simulate_sale_render.py` uses, for the same reason —
the tool spells the view id as a plain string, because `app.agent` may not
import `app.presentation`, which makes the id and its options two
declarations of one fact.
"""

from app.agent.contracts import ToolContext
from app.agent.tools.compare_methods import VIEW, CompareLotMethodsTool
from app.presentation.registry import REGISTRY
from app.presentation.resolve import validated_options
from app.presentation.scenario_options import ScenarioComparisonOptions
from app.presentation.scenario_payload import ScenarioComparisonPayload
from tests.unit.agent.tools.compare_fixtures import (
    THREE_QUARTERS,
    TWENTY_THOUSAND,
    columns,
    subject,
)
from tests.unit.agent.tools.compare_fixtures import tool as tool

__all__ = ["tool"]


async def test_a_successful_comparison_asks_for_the_comparison_card(
    tool: CompareLotMethodsTool, tool_context: ToolContext
) -> None:
    """AC-1 — the scenario named is the one that was costed."""
    outcome = await tool.run(
        {**THREE_QUARTERS, "methods": ["FIFO", "HIFO"]}, tool_context
    )

    assert outcome.render is not None
    assert outcome.render.view == VIEW
    assert dict(outcome.render.options) == {
        "symbol": "BTC",
        "quantity": "0.75",
        "methods": ["FIFO", "HIFO"],
        "include_wait": False,
    }


async def test_the_intent_names_a_projection_the_registry_really_holds(
    tool: CompareLotMethodsTool, tool_context: ToolContext
) -> None:
    """AC-1 — the tool's ``VIEW`` string and the view's own id are compared here.

    ``REGISTRY.get`` raises ``UnknownViewError`` for an id nobody registered,
    so a renamed projection fails this test instead of failing a demo. It is
    the check whose absence *was* the ticket, one level down.
    """
    outcome = await tool.run(TWENTY_THOUSAND, tool_context)

    assert outcome.render is not None
    assert REGISTRY.get(outcome.render.view).id == VIEW


async def test_the_intents_options_validate_against_the_projections_own_model(
    tool: CompareLotMethodsTool, tool_context: ToolContext
) -> None:
    """AC-1 — an option the view does not declare would be a 422, not a render."""
    outcome = await tool.run({**TWENTY_THOUSAND, "include_wait": True}, tool_context)

    assert outcome.render is not None
    projection = REGISTRY.get(outcome.render.view)
    options = validated_options(projection, outcome.render.options)

    assert isinstance(options, ScenarioComparisonOptions)
    assert options.symbol == "BTC"
    assert options.include_wait is True


async def test_the_rendered_card_names_what_the_answer_names(
    tool: CompareLotMethodsTool, tool_context: ToolContext
) -> None:
    """AC-3 — the card and the sentence under it must not disagree.

    Two methods rather than three, because a render intent that dropped
    ``methods`` would still draw a plausible card — with all three columns —
    and only a comparison like this one would notice.
    """
    portfolio = await tool_context.portfolios.get(tool_context.owner)
    outcome = await tool.run(
        {**TWENTY_THOUSAND, "methods": ["LIFO", "HIFO"]}, tool_context
    )

    assert outcome.render is not None
    projection = REGISTRY.get(outcome.render.view)
    payload = projection.render(
        portfolio, validated_options(projection, outcome.render.options)
    )

    assert isinstance(payload, ScenarioComparisonPayload)
    assert [column.method for column in payload.columns] == ["LIFO", "HIFO"]
    assert payload.subject.symbol == subject(outcome.data["subject"])["symbol"]
    assert [column.realized_pl.display for column in payload.columns] == [
        row["realizedPlDisplay"] for row in columns(outcome.data["columns"])
    ]


async def test_a_dollar_sized_ask_travels_as_the_units_it_resolved_to(
    tool: CompareLotMethodsTool, tool_context: ToolContext
) -> None:
    """AC-1 — the model never divides: the tool resolved the size.

    The card must cost the units the columns were costed with, or the
    sentence names one sale and the table draws another.
    """
    portfolio = await tool_context.portfolios.get(tool_context.owner)
    outcome = await tool.run(TWENTY_THOUSAND, tool_context)

    assert outcome.render is not None
    projection = REGISTRY.get(outcome.render.view)
    payload = projection.render(
        portfolio, validated_options(projection, outcome.render.options)
    )

    assert isinstance(payload, ScenarioComparisonPayload)
    said = subject(outcome.data["subject"])
    assert payload.subject.quantity_display == said["quantityDisplay"]
    assert payload.subject.price.display == said["priceDisplay"]
