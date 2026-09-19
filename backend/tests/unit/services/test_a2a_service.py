"""Spec 0010 — the adapter's own behaviour, including the failure path."""

import json

import pytest

from app.agent.contracts import ToolContext
from app.core.errors import DependencyUnavailableError
from app.core.model import ModelReply
from app.infra.model.null_client import NullModelClient
from app.schemas.a2a import ClientMessage
from app.services.a2a_service import (
    COMPLETED,
    FAILED,
    INPUT_REQUIRED,
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


def test_a_message_joins_its_text_parts() -> None:
    message = ClientMessage.model_validate(
        {
            "role": "user",
            "parts": [
                {"kind": "text", "text": "why did"},
                {"kind": "text", "text": "I move?"},
            ],
        }
    )

    assert message.text() == "why did I move?"


@pytest.mark.parametrize(
    "payload",
    [
        {"role": "user", "parts": []},
        {"role": "agent", "parts": [{"kind": "text", "text": "hi"}]},
    ],
    ids=["no_parts", "not_the_user"],
)
def test_a_message_the_protocol_does_not_allow_is_rejected(
    payload: dict[str, object],
) -> None:
    with pytest.raises(ValueError, match="validation error"):
        ClientMessage.model_validate(payload)
