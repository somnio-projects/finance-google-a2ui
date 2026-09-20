"""Spec 0006 AC-11/AC-12 — the failures a turn absorbs, and the one it does not."""

import pytest

from app.agent.contracts import ToolContext
from app.agent.registry import ToolRegistry
from app.core.errors import DependencyUnavailableError
from app.core.model import ModelReply
from app.helpers.clock import FixedClock
from app.infra.model.null_client import NullModelClient
from app.services.agent_service import TURN_METRIC, AgentService
from app.services.agent_tools import TOOL_FAILED_ERROR, UNKNOWN_TOOL_ERROR
from tests.conftest import FROZEN_NOW, FakeReporter
from tests.unit.conftest import FakeTool
from tests.unit.services.agent_doubles import (
    ANSWER,
    TEST_PROMPT,
    FailingModel,
    call,
    make_service,
    tool_results,
)


async def test_run_turn_reports_a_failing_tool_and_still_answers(
    tool_context: ToolContext,
) -> None:
    failure = RuntimeError("boom")
    broken = FakeTool(error=failure)
    model = NullModelClient([ModelReply(tool_calls=(call(),)), ModelReply(text=ANSWER)])
    service, reporter = make_service(model, tools=[broken])

    result = await service.run_turn(prompt="hi", history=[], context=tool_context)

    assert result.message == ANSWER
    assert result.tool_calls == 1
    assert result.render_intents == ()
    assert tool_results(model) == [dict(TOOL_FAILED_ERROR)]
    assert reporter.exceptions == [failure]


async def test_run_turn_answers_an_unknown_tool_without_reporting_it(
    tool_context: ToolContext, fake_tool: FakeTool
) -> None:
    model = NullModelClient(
        [
            ModelReply(tool_calls=(call("hallucinated_tool", call_id="0-hall"),)),
            ModelReply(text=ANSWER),
        ]
    )
    service, reporter = make_service(model, tools=[fake_tool])

    result = await service.run_turn(prompt="hi", history=[], context=tool_context)

    assert result.message == ANSWER
    assert tool_results(model) == [dict(UNKNOWN_TOOL_ERROR)]
    assert reporter.exceptions == []
    assert fake_tool.seen == []


async def test_run_turn_reports_and_reraises_a_model_failure(
    tool_context: ToolContext,
) -> None:
    failure = DependencyUnavailableError("model provider unavailable")
    reporter = FakeReporter()
    service = AgentService(
        model=FailingModel(failure),
        tools=ToolRegistry(),
        reporter=reporter,
        clock=FixedClock(FROZEN_NOW),
        max_iterations=4,
        system_prompt=TEST_PROMPT,
    )

    with pytest.raises(DependencyUnavailableError, match="model provider unavailable"):
        await service.run_turn(prompt="hi", history=[], context=tool_context)

    assert reporter.exceptions == [failure]
    assert reporter.metrics == [
        (TURN_METRIC, {"model": "failing", "outcome": "model-unavailable"})
    ]


async def test_run_turn_reports_and_counts_an_untyped_failure(
    tool_context: ToolContext,
) -> None:
    """A provider that raises something untranslated must still be reported.

    This is the one path the A2A adapter can only turn into a terminal event:
    by then the client holds a 200, so the stream swallows the exception. If
    the turn did not report and count it here, an exploding model provider
    would be invisible — no Sentry event and no `agent.turn` metric at all.
    """
    failure = RuntimeError("the provider SDK changed its mind")
    reporter = FakeReporter()
    service = AgentService(
        model=FailingModel(failure),
        tools=ToolRegistry(),
        reporter=reporter,
        clock=FixedClock(FROZEN_NOW),
        max_iterations=4,
        system_prompt=TEST_PROMPT,
    )

    with pytest.raises(RuntimeError, match="changed its mind"):
        await service.run_turn(prompt="hi", history=[], context=tool_context)

    assert reporter.exceptions == [failure]
    assert reporter.metrics == [(TURN_METRIC, {"model": "failing", "outcome": "error"})]
