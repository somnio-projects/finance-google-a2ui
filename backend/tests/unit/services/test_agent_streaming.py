"""Spec 0012 AC-1, AC-2, AC-3 — the turn loop yields as it goes.

What these assert is *timing*, not content: a surface must leave the loop
before the turn is finished. A test that only checked the final list would
pass against the old implementation, which is exactly the regression this
change exists to prevent.
"""

import pytest

from app.agent.contracts import RenderIntent, ToolContext, ToolOutcome
from app.agent.events import SurfaceReady, TurnCompleted, TurnEvent
from app.core.errors import DependencyUnavailableError
from app.core.model import ModelReply
from app.infra.model.null_client import NullModelClient
from app.services.agent_service import AgentService
from app.services.agent_telemetry import TURN_METRIC
from tests.conftest import FakeReporter
from tests.unit.conftest import FakeTool
from tests.unit.services.agent_doubles import ANSWER, FailingModel, call, make_service

ALLOCATION = "holdings.allocation.v1"
WATERFALL = "attribution.waterfall.v1"


def _tool(view: str, *, name: str) -> FakeTool:
    tool = FakeTool(
        outcome=ToolOutcome(
            data={"answerDisplay": "$1.00"}, render=RenderIntent(view=view)
        )
    )
    tool.name = name
    return tool


async def _events(service: AgentService, context: ToolContext) -> list[TurnEvent]:
    return [
        event
        async for event in service.run_turn_events(
            prompt="why did I move?", history=[], context=context
        )
    ]


async def test_a_surface_is_emitted_before_the_turn_completes(
    tool_context: ToolContext,
) -> None:
    """The whole point of AC-1: the first widget beats the last word.

    The tool's render intent must arrive as its own event *ahead of* the
    ``TurnCompleted`` that carries the answer — otherwise the stream is still
    one burst and ADR-K D-19 is unmet.
    """
    tool = _tool(ALLOCATION, name="fake_tool")
    model = NullModelClient(
        [ModelReply(tool_calls=(call(tool.name),)), ModelReply(text=ANSWER)]
    )
    service, _ = make_service(model, tools=[tool])

    events = await _events(service, tool_context)

    assert isinstance(events[0], SurfaceReady)
    assert events[0].intent.view == ALLOCATION
    assert events[0].index == 0
    assert isinstance(events[-1], TurnCompleted)
    assert events[-1].result.message == ANSWER


async def test_every_surface_is_emitted_once_and_in_order(
    tool_context: ToolContext,
) -> None:
    """Two tools in one model reply give two events, indexed 0 and 1."""
    first = _tool(ALLOCATION, name="first_tool")
    second = _tool(WATERFALL, name="second_tool")
    model = NullModelClient(
        [
            ModelReply(
                tool_calls=(
                    call(first.name, call_id="0-a"),
                    call(second.name, call_id="1-b"),
                )
            ),
            ModelReply(text=ANSWER),
        ]
    )
    service, _ = make_service(model, tools=[first, second])

    events = await _events(service, tool_context)
    surfaces = [event for event in events if isinstance(event, SurfaceReady)]

    assert [(surface.index, surface.intent.view) for surface in surfaces] == [
        (0, ALLOCATION),
        (1, WATERFALL),
    ]


async def test_a_turn_with_no_tool_emits_only_the_completion(
    tool_context: ToolContext,
) -> None:
    service, _ = make_service(NullModelClient([ModelReply(text=ANSWER)]))

    events = await _events(service, tool_context)

    assert len(events) == 1
    assert isinstance(events[0], TurnCompleted)


async def test_run_turn_still_returns_the_finished_result(
    tool_context: ToolContext,
) -> None:
    """AC-3 — the collector is unchanged for every caller that wants a value."""
    tool = _tool(ALLOCATION, name="fake_tool")
    model = NullModelClient(
        [ModelReply(tool_calls=(call(tool.name),)), ModelReply(text=ANSWER)]
    )
    service, _ = make_service(model, tools=[tool])

    result = await service.run_turn(
        prompt="why did I move?", history=[], context=tool_context
    )

    assert result.message == ANSWER
    assert [intent.view for intent in result.render_intents] == [ALLOCATION]
    assert result.tool_calls == 1


async def test_a_dead_model_is_reported_once_and_re_raised(
    tool_context: ToolContext,
) -> None:
    """The failure path still records exactly one turn metric (spec 0006 AC-13)."""
    error = DependencyUnavailableError("model provider unavailable")
    service, reporter = make_service(FailingModel(error))

    with pytest.raises(DependencyUnavailableError, match="model provider unavailable"):
        await _events(service, tool_context)

    assert reporter.exceptions == [error]
    assert _outcomes(reporter) == ["model-unavailable"]


def _outcomes(reporter: FakeReporter) -> list[str]:
    """Return the outcome tag of every turn metric the reporter received."""
    return [
        tags["outcome"] for metric, tags in reporter.metrics if metric == TURN_METRIC
    ]
