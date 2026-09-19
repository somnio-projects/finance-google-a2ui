"""Spec 0010 — the adapter's own behaviour, including the failure path."""

import json

from app.agent.contracts import ToolContext
from app.core.errors import DependencyUnavailableError
from app.core.model import ModelReply
from app.infra.model.null_client import NullModelClient
from app.schemas.a2a import ClientMessage
from app.services.a2a_service import (
    COMPLETED,
    FAILED,
    INPUT_REQUIRED,
    TURN_FAILED,
    WORKING,
    A2aService,
    sse,
)
from app.services.agent_service import AgentService
from tests.unit.conftest import FakeTool
from tests.unit.services.agent_doubles import ANSWER, call, make_service


def _message(text: str = "why did I move?") -> ClientMessage:
    return ClientMessage.model_validate(
        {"role": "user", "parts": [{"kind": "text", "text": text}]}
    )


async def _collect(
    service: A2aService, context: ToolContext
) -> list[dict[str, object]]:
    return [
        json.loads(chunk.removeprefix("data: ").strip())
        async for chunk in service.stream(
            message=_message(), task_id="task-1", context=context
        )
    ]


def test_sse_frames_a_payload_with_the_blank_line_the_protocol_requires() -> None:
    assert sse({"a": 1}) == 'data: {"a":1}\n\n'


async def test_a_turn_with_no_surface_ends_completed(tool_context: ToolContext) -> None:
    service, _ = make_service(NullModelClient([ModelReply(text=ANSWER)]))

    events = await _collect(A2aService(agent=service), tool_context)

    states = [event["status"] for event in events if "status" in event]

    assert states == [{"state": WORKING}, {"state": COMPLETED}]


async def test_a_turn_that_produced_a_surface_ends_input_required(
    tool_context: ToolContext,
) -> None:
    """ADR-D D-3 — a surface awaiting the user is terminal, not an error.

    The client must not show an error here, which is exactly the mistake a
    client makes when the server calls this state `failed`.
    """
    tool = FakeTool()
    model = NullModelClient(
        [ModelReply(tool_calls=(call(tool.name),)), ModelReply(text=ANSWER)]
    )
    service, _ = make_service(model, tools=[tool])

    events = await _collect(A2aService(agent=service), tool_context)

    assert events[-1]["status"] == {"state": INPUT_REQUIRED}
    assert events[-1]["final"] is True


async def test_a_failing_turn_reports_inside_the_stream(
    tool_context: ToolContext,
) -> None:
    """By the time a turn can fail the client already has a 200 and a header.

    So the failure has to travel as an event. A transport-level error would
    arrive after the response had already started, which no client can read.
    """

    class Failing(AgentService):
        async def run_turn(self, **_: object) -> None:  # type: ignore[override]
            raise DependencyUnavailableError("model provider unavailable")

    service = A2aService(agent=Failing.__new__(Failing))

    events = [
        json.loads(chunk.removeprefix("data: ").strip())
        async for chunk in service.stream(
            message=_message(), task_id="t", context=tool_context
        )
    ]

    assert events[0]["status"] == {"state": WORKING}
    assert events[1]["status"] == {"state": FAILED}
    assert events[2]["kind"] == "error"
    assert events[2]["message"] == "model provider unavailable"


async def test_an_unexpected_failure_still_ends_the_stream(
    tool_context: ToolContext,
) -> None:
    """The failure mode a client cannot recover from if we get it wrong.

    A bug in a tool, a projection or the dump of a render intent raises
    something that is not an ``AppError``. The response has already started,
    so the 500 handler has no body left to send: the client would be left with
    a truncated stream whose last state is ``working`` and no ``final`` event,
    and no way to know the turn is over. Catching it here and emitting the
    terminal pair is reporting, not swallowing.
    """

    class Exploding(AgentService):
        async def run_turn(self, **_: object) -> None:  # type: ignore[override]
            raise RuntimeError("a tool has a bug")

    service = A2aService(agent=Exploding.__new__(Exploding))

    events = [
        json.loads(chunk.removeprefix("data: ").strip())
        async for chunk in service.stream(
            message=_message(), task_id="t", context=tool_context
        )
    ]

    assert [event.get("status", {}).get("state") for event in events] == [
        WORKING,
        FAILED,
        None,
    ]
    assert events[1]["final"] is True
    assert events[2]["message"] == TURN_FAILED
    assert "bug" not in json.dumps(events), "the exception's text must not leak"
