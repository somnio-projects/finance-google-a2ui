"""Spec 0056 AC-3 — a turn an action pinned asks no model.

Asserted on the null model's own call log: if ``generate`` were awaited even
once the list would not be empty, which is the regression this exists for.
"""

from collections.abc import Mapping

from app.actions.contracts import DirectCall
from app.agent.contracts import RenderIntent, ToolContext, ToolOutcome
from app.agent.events import SurfaceReady, TurnCompleted, TurnEvent
from app.infra.model.null_client import NullModelClient
from app.services.agent_service import AgentService
from app.services.agent_telemetry import TURN_METRIC
from tests.unit.conftest import FakeTool
from tests.unit.services.agent_doubles import make_service

DRIVER = "attribution.driver.v1"


def _echo(result: Mapping[str, object]) -> str:
    """Narrate by quoting the result, so the test sees what the turn fed it."""
    return f"said {dict(result)!r}"


async def _events(
    service: AgentService, context: ToolContext, direct: DirectCall
) -> list[TurnEvent]:
    return [
        event
        async for event in service.run_turn_events(
            prompt="drill", history=[], context=context, direct=direct
        )
    ]


async def test_direct_turn_runs_the_tool_and_never_calls_the_model(
    tool_context: ToolContext,
) -> None:
    """The surface leaves first, then the narration; the model is untouched."""
    tool = FakeTool(
        outcome=ToolOutcome(
            data={"held": True},
            render=RenderIntent(view=DRIVER, options={"symbol": "BTC"}),
        )
    )
    model = NullModelClient()
    service, reporter = make_service(model, tools=[tool])
    direct = DirectCall(tool=tool.name, arguments={"symbol": "BTC"}, answer=_echo)

    events = await _events(service, tool_context, direct)

    assert model.calls == []
    assert tool.seen == [{"symbol": "BTC"}]
    assert isinstance(events[0], SurfaceReady)
    assert events[0].intent.view == DRIVER
    assert isinstance(events[-1], TurnCompleted)
    result = events[-1].result
    assert result.message == "said {'held': True}"
    assert (result.iterations, result.tool_calls) == (0, 1)
    assert [name for name, _ in reporter.metrics] == [TURN_METRIC]


async def test_direct_turn_with_an_unknown_tool_is_narrated_not_raised(
    tool_context: ToolContext,
) -> None:
    """A tool the registry lacks reaches the narration as its error marker."""
    model = NullModelClient()
    service, _ = make_service(model)
    direct = DirectCall(tool="nope", arguments={}, answer=_echo)

    events = await _events(service, tool_context, direct)

    assert model.calls == []
    assert len(events) == 1
    assert isinstance(events[0], TurnCompleted)
    assert events[0].result.message == "said {'error': 'unknown-tool'}"
    assert events[0].result.render_intents == ()
