"""Translate an A2A call into a turn, and a turn into protocol events.

This is the **thin adapter** ADR-J D-2 requires: it knows the protocol envelope
and nothing else. No business rule lives here, and `AgentService` does not know
the protocol exists — which is what lets A2A move (it is alpha) without the
services moving with it.

**What this does not do yet, stated plainly:**

- *Conversation history.* `contextId` is echoed for correlation but no history
  is loaded, because sessions (GGU-46) are not on this branch. Every turn
  currently starts empty. The resolution rule is already decided (ADR-J D-4,
  ADR-A): a `contextId` is resolved **against the authenticated subject** or
  treated as unknown, never trusted on its own.
- *Incremental streaming.* ADR-K D-19 wants each surface emitted as it is
  ready. `AgentService.run_turn` returns a finished turn rather than yielding,
  so the stream here is well-formed but not incremental: a `working` event,
  then the result. Making the loop a generator is the follow-up, and it changes
  this module only.
"""

import json
from collections.abc import AsyncIterator
from typing import Final

from app.agent.contracts import ToolContext
from app.core.errors import AppError
from app.schemas.a2a import ClientMessage
from app.services.agent_service import AgentService

WORKING: Final[str] = "working"
COMPLETED: Final[str] = "completed"
FAILED: Final[str] = "failed"
#: A turn that produced a surface awaiting the user is a normal terminal state,
#: not an error — the client must not treat it as one (ADR-D D-3).
INPUT_REQUIRED: Final[str] = "input_required"


def sse(payload: dict[str, object]) -> str:
    """Frame one JSON payload as a server-sent event.

    Args:
        payload: The event body.

    Returns:
        The wire text, terminated by the blank line SSE requires.
    """
    return f"data: {json.dumps(payload, separators=(',', ':'))}\n\n"


def _status(task_id: str, context_id: str | None, state: str) -> dict[str, object]:
    """Build a task-status event."""
    return {
        "kind": "status-update",
        "taskId": task_id,
        "contextId": context_id,
        "status": {"state": state},
        "final": state != WORKING,
    }


class A2aService:
    """Run one A2A `message/stream` call as a turn, and emit its events."""

    def __init__(self, *, agent: AgentService) -> None:
        """Bind the adapter to the agent host it delegates to."""
        self._agent = agent

    async def stream(
        self, *, message: ClientMessage, task_id: str, context: ToolContext
    ) -> AsyncIterator[str]:
        """Yield the events of one turn, in protocol order.

        Args:
            message: The client's message, already validated.
            task_id: Correlation id for this turn.
            context: The subject-scoped tool context.

        Yields:
            Server-sent events: a `working` status, then either the answer and
            a terminal status, or a terminal `failed` status. A failure is
            reported **inside the stream** rather than as a transport error,
            because the client has already received a 200 and a header by the
            time a turn can fail.
        """
        yield sse(_status(task_id, message.context_id, WORKING))
        try:
            result = await self._agent.run_turn(
                prompt=message.text(), history=[], context=context
            )
        except AppError as exc:
            yield sse(_status(task_id, message.context_id, FAILED))
            yield sse(
                {
                    "kind": "error",
                    "taskId": task_id,
                    "code": exc.code,
                    "message": exc.detail,
                }
            )
            return
        yield sse(
            {
                "kind": "message",
                "taskId": task_id,
                "contextId": message.context_id,
                "role": "agent",
                "parts": [{"kind": "text", "text": result.message}],
                "renderIntents": [
                    intent.model_dump(mode="json") for intent in result.render_intents
                ],
            }
        )
        terminal = INPUT_REQUIRED if result.render_intents else COMPLETED
        yield sse(_status(task_id, message.context_id, terminal))


__all__ = [
    "COMPLETED",
    "FAILED",
    "INPUT_REQUIRED",
    "WORKING",
    "A2aService",
    "sse",
]
