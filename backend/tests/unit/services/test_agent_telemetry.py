"""Spec 0006 AC-13 — one metric and one log line per turn, and nothing sensitive."""

import structlog

from app.agent.contracts import ToolContext
from app.core.model import ModelReply
from app.infra.model.null_client import NullModelClient
from app.services.agent_service import TURN_METRIC
from tests.unit.conftest import FakeTool
from tests.unit.services.agent_doubles import ANSWER, call, make_service


def answering_script() -> NullModelClient:
    """A model that asks for one tool, then answers."""
    return NullModelClient([ModelReply(tool_calls=(call(),)), ModelReply(text=ANSWER)])


async def test_run_turn_records_one_metric_per_successful_turn(
    tool_context: ToolContext, fake_tool: FakeTool
) -> None:
    service, reporter = make_service(answering_script(), tools=[fake_tool])

    await service.run_turn(prompt="hi", history=[], context=tool_context)

    assert reporter.metrics == [(TURN_METRIC, {"model": "null", "outcome": "ok"})]


async def test_the_turn_log_line_carries_no_prompt_no_result_and_no_subject(
    tool_context: ToolContext, fake_tool: FakeTool
) -> None:
    service, _ = make_service(answering_script(), tools=[fake_tool])

    with structlog.testing.capture_logs() as logs:
        await service.run_turn(
            prompt="how much NVDA do I hold?", history=[], context=tool_context
        )

    turns = [entry for entry in logs if entry["event"] == TURN_METRIC]
    assert len(turns) == 1
    assert set(turns[0]) == {
        "event",
        "log_level",
        "model",
        "outcome",
        "duration_ms",
        "iterations",
        "tool_calls",
    }
    assert turns[0]["outcome"] == "ok"
    rendered = str(turns[0])
    assert "NVDA" not in rendered
    assert tool_context.owner not in rendered
    assert ANSWER not in rendered


async def test_a_failing_tool_is_logged_by_type_never_by_message(
    tool_context: ToolContext,
) -> None:
    broken = FakeTool(error=RuntimeError("stack trace and secrets"))
    service, _ = make_service(answering_script(), tools=[broken])

    with structlog.testing.capture_logs() as logs:
        await service.run_turn(prompt="hi", history=[], context=tool_context)

    failures = [entry for entry in logs if entry["event"] == "agent.tool.failed"]
    assert failures[0]["error"] == "RuntimeError"
    assert "secrets" not in str(failures[0])


async def test_an_unknown_tool_is_logged_by_name(tool_context: ToolContext) -> None:
    model = NullModelClient(
        [
            ModelReply(tool_calls=(call("hallucinated_tool", call_id="0-hall"),)),
            ModelReply(text=ANSWER),
        ]
    )
    service, _ = make_service(model)

    with structlog.testing.capture_logs() as logs:
        await service.run_turn(prompt="hi", history=[], context=tool_context)

    unknown = [entry for entry in logs if entry["event"] == "agent.tool.unknown"]
    assert unknown[0]["tool"] == "hallucinated_tool"
