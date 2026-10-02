"""Spec 0053 §3 — a v1.0 turn that fails ends with the v0.9 failure pair.

By the time anything can fail the client holds a 200, so a failure is the
terminal ``failed`` status and a safe ``error`` event inside the stream — and
the exception reaches the reporter, whichever layer raised it.
"""

import pytest

from app.agent.contracts import ToolContext
from app.core.errors import DependencyUnavailableError
from app.core.principal import Principal
from app.services.a2ui_v1_payloads import PayloadRenderer
from app.services.a2ui_v1_turn import V1TurnStream
from tests.unit.services.a2ui_v1_doubles import collect, views
from tests.unit.services.agent_doubles import FailingModel, make_service


@pytest.mark.parametrize(
    ("error", "code"),
    [
        (DependencyUnavailableError("model down"), "dependency-unavailable"),
        (RuntimeError("boom"), "internal"),
    ],
    ids=["typed-failure", "untyped-failure"],
)
async def test_a_failing_turn_ends_with_the_failure_pair(
    principal: Principal, tool_context: ToolContext, error: Exception, code: str
) -> None:
    agent, reporter = make_service(FailingModel(error))  # type: ignore[arg-type]
    stream = V1TurnStream(
        agent=agent,
        payloads=PayloadRenderer(views=views(), principal=principal),
        reporter=reporter,
    )

    events = await collect(
        stream.stream(prompt="x", task_id="t", context_id=None, context=tool_context)
    )

    assert [event["kind"] for event in events] == [
        "status-update",
        "status-update",
        "error",
    ]
    assert events[1]["status"] == {"state": "failed"}
    assert events[-1]["code"] == code
    assert error in reporter.exceptions
