"""Spec 0033 AC-5 — every scripted prompt is a whole turn over the real tools.

Nothing here is a double except the portfolio provider, which is the seeded
in-memory one every tool test already runs against. The model is the scripted
client the factory selects without a key, the tools are the discovered
registry, and the render intents pass through the real projection registry —
so what this asserts is what the Assistant tab shows on a stack with no
``GEMINI_API_KEY``.
"""

from collections.abc import Mapping

import pytest

from app.agent.contracts import ToolContext, TurnResult
from app.agent.registry import load_tools
from app.helpers.clock import FixedClock
from app.infra.model.demo_script import DEMO_SCRIPTS, FLOW_A, FLOW_B, FLOW_C
from app.infra.model.null_client import UNCONFIGURED_MESSAGE
from app.infra.model.script import PLACEHOLDER, TOOLS_FAILED_MESSAGE, flatten
from app.infra.model.scripted_client import ScriptedModelClient
from app.services.agent_service import AgentService
from app.services.agent_telemetry import TURN_METRIC
from tests.conftest import FROZEN_NOW, FakeReporter
from tests.unit.services.agent_doubles import TEST_PROMPT, make_resolver

#: Which projection each tool draws with — the tool's own declaration, held
#: here as the second copy so a tool that stops drawing fails this file.
SURFACE_OF: Mapping[str, str | None] = {
    "compute_attribution": "attribution.waterfall.v1",
    "get_holdings_summary": "holdings.allocation.v1",
    "simulate_sale": "taxlots.table.v1",
    "draft_order": "order.ticket.v2",
    "driver_detail": "attribution.driver.v1",
}

#: The design's Flow A sentence, with the seed's own figures (spec 0025 §2):
#: the one literal oracle, hand-checked against the artboard's +$3,240 (0.68%).
FLOW_A_OPENING = "Your portfolio is up +$3,240.18 (0.68%) today. Here's what drove it:"


async def run(
    prompt: str, tool_context: ToolContext
) -> tuple[TurnResult, ScriptedModelClient, FakeReporter]:
    """Run one turn as the wired stack would, minus the HTTP layer."""
    model = ScriptedModelClient()
    reporter = FakeReporter()
    service = AgentService(
        model=model,
        tools=load_tools(),
        reporter=reporter,
        renders=make_resolver(reporter),
        clock=FixedClock(FROZEN_NOW),
        max_iterations=4,
        system_prompt=TEST_PROMPT,
    )
    result = await service.run_turn(prompt=prompt, history=[], context=tool_context)
    return result, model, reporter


@pytest.mark.parametrize("key", sorted(DEMO_SCRIPTS), ids=sorted(DEMO_SCRIPTS))
async def test_every_scripted_prompt_draws_its_surfaces_and_copies_its_figures(
    key: str, tool_context: ToolContext
) -> None:
    script = DEMO_SCRIPTS[key]
    portfolio = await tool_context.portfolios.get(tool_context.owner)
    held = {holding.symbol for holding in portfolio.holdings()}

    result, model, reporter = await run(key, tool_context)

    if any(call.arguments.get("symbol") not in held | {None} for call in script.calls):
        # A drill on a market symbol the seed does not hold: the tool answers
        # ``held: false``, draws nothing, and the script says its own sentence.
        assert result.render_intents == ()
        assert result.message == script.otherwise
        assert reporter.exceptions == []
        return
    expected_views = [
        SURFACE_OF[call.name]
        for call in script.calls
        if SURFACE_OF[call.name] is not None
    ]
    assert [intent.view for intent in result.render_intents] == expected_views
    assert result.tool_calls == len(script.calls)
    assert result.iterations == 2
    assert result.truncated is False
    assert result.message not in {UNCONFIGURED_MESSAGE, TOOLS_FAILED_MESSAGE}
    assert not PLACEHOLDER.search(result.message)
    assert reporter.exceptions == []
    # Every hole was filled with the string the loop fed back, verbatim.
    fed_back: dict[str, str] = {}
    for message in model.calls[-1].messages:
        if message.tool_result is not None:
            fed_back.update(flatten(message.tool_result))
    for hole in PLACEHOLDER.findall(script.answer):
        assert fed_back[hole] in result.message


async def test_flow_a_says_the_designs_sentence_with_the_seeds_figures(
    tool_context: ToolContext,
) -> None:
    result, _, _ = await run(FLOW_A, tool_context)

    assert result.message == FLOW_A_OPENING
    assert [intent.view for intent in result.render_intents] == [
        "attribution.waterfall.v1"
    ]


async def test_flow_b_costs_the_designs_sale_and_draws_the_lots(
    tool_context: ToolContext,
) -> None:
    result, _, _ = await run(FLOW_B, tool_context)

    (intent,) = result.render_intents
    assert intent.view == "taxlots.table.v1"
    assert intent.options["symbol"] == "NVDA"
    assert intent.options["lot_method"] == "FIFO"
    assert "NVDA sold under FIFO raises $20,000.00" in result.message


async def test_flow_c_drafts_the_designs_basket_and_draws_the_ticket(
    tool_context: ToolContext,
) -> None:
    result, _, _ = await run(FLOW_C, tool_context)

    (intent,) = result.render_intents
    assert intent.view == "order.ticket.v2"
    assert intent.options == {"legs": "NVDA:3,AVGO:2,AMD:14", "side": "buy"}
    assert result.message.startswith("Here is a draft across the semiconductor basket:")
    assert "nothing is placed" in result.message


async def test_a_prompt_outside_the_table_still_answers_honestly(
    tool_context: ToolContext,
) -> None:
    result, model, reporter = await run("what do I hold?", tool_context)

    assert result.message == UNCONFIGURED_MESSAGE
    assert result.render_intents == ()
    assert result.tool_calls == 0
    assert model.calls[0].system == TEST_PROMPT
    assert [spec.name for spec in model.calls[0].tools] == list(load_tools().names())
    assert reporter.metrics == [(TURN_METRIC, {"model": "scripted", "outcome": "ok"})]
