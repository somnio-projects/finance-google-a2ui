"""Spec 0012 AC-2 — the adapter forwards each surface as the turn produces it.

Separate from ``test_a2a_service`` because it asserts a different property:
that module pins the protocol's shapes and its failure path, this one pins the
*order* the events arrive in, which is the whole of ADR-K D-19.
"""

import json
from typing import Any

from app.agent.contracts import ToolContext
from app.core.model import ModelReply
from app.infra.model.null_client import NullModelClient
from app.schemas.a2a import ClientMessage
from app.services.a2a_service import A2aService
from tests.unit.conftest import FakeTool
from tests.unit.services.agent_doubles import ANSWER, call, make_service

ALLOCATION = "holdings.allocation.v1"


def _message() -> ClientMessage:
    return ClientMessage.model_validate(
        {"role": "user", "parts": [{"kind": "text", "text": "why did I move?"}]}
    )


async def _events(context: ToolContext) -> list[dict[str, Any]]:
    """Run one turn whose single tool produces one surface, and collect it."""
    tool = FakeTool()
    model = NullModelClient(
        [ModelReply(tool_calls=(call(tool.name),)), ModelReply(text=ANSWER)]
    )
    service, _ = make_service(model, tools=[tool])
    return [
        json.loads(chunk.removeprefix("data: ").strip())
        async for chunk in A2aService(agent=service).stream(
            message=_message(),
            prompt=_message().text(),
            task_id="task-1",
            context=context,
        )
    ]


async def test_a_surface_is_streamed_before_the_answer(
    tool_context: ToolContext,
) -> None:
    """The client can paint a widget mid-turn.

    The `render-intent` event must precede the terminal `message`. A client
    that waits for the message to read `renderIntents` still works, which is
    why both carry the intent; what changed is that it no longer has to.
    """
    events = await _events(tool_context)
    kinds = [event.get("kind") for event in events]

    assert kinds.index("render-intent") < kinds.index("message")
    surface = events[kinds.index("render-intent")]
    assert surface["renderIntent"]["view"] == ALLOCATION
    assert surface["index"] == 0
    assert surface["taskId"] == "task-1"


async def test_the_terminal_message_still_carries_every_intent(
    tool_context: ToolContext,
) -> None:
    """The incremental events are additive; spec 0010 AC-2 is unchanged."""
    events = await _events(tool_context)
    message = next(event for event in events if event.get("kind") == "message")

    assert [intent["view"] for intent in message["renderIntents"]] == [ALLOCATION]
    assert message["parts"] == [{"kind": "text", "text": ANSWER}]
