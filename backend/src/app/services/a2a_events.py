"""The wire shapes one A2A turn emits, and nothing else.

Split from ``a2a_service`` when the stream became incremental: that module now
answers *what happened while we answered*, while this one answers *what the
bytes look like*. Keeping the shapes here is what makes the protocol's alpha
status cheap — A2A moves, one module follows it, and the turn loop never
learns the protocol exists (ADR-J D-2).

**On `render-intent`.** A2A has no event for "a surface is ready", so this
surface adds one, additively: a client that ignores it is unaffected, because
the terminal `message` event still carries the full `renderIntents` list. The
incremental events are what make the first widget appear early (ADR-K D-19);
the list is what keeps the contract spec 0010 AC-2 pinned.
"""

import json
from typing import Final

from app.actions.suggestions import suggestion_chips
from app.agent.contracts import RenderIntent

TURN_FAILED: Final[str] = "The turn could not be completed."
INTERNAL: Final[str] = "internal"

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


def status(task_id: str, context_id: str | None, state: str) -> dict[str, object]:
    """Build a task-status event.

    Args:
        task_id: Correlation id of this turn.
        context_id: The conversation the client believes this belongs to.
        state: One of the task states above.

    Returns:
        The event body; ``final`` is true for every state but ``working``.
    """
    return {
        "kind": "status-update",
        "taskId": task_id,
        "contextId": context_id,
        "status": {"state": state},
        "final": state != WORKING,
    }


def failed(
    task_id: str, context_id: str | None, code: str, detail: str
) -> list[dict[str, object]]:
    """Return the terminal pair a failed turn ends with.

    Args:
        task_id: Correlation id of this turn.
        context_id: The conversation id to echo.
        code: A safe, stable error code — never internal text.
        detail: A safe, human-readable explanation.

    Returns:
        The `failed` status followed by the error event.
    """
    return [
        status(task_id, context_id, FAILED),
        {"kind": "error", "taskId": task_id, "code": code, "message": detail},
    ]


def surface(
    task_id: str, context_id: str | None, index: int, intent: RenderIntent
) -> dict[str, object]:
    """Build the event that carries one ready surface (ADR-K D-19).

    Args:
        task_id: Correlation id of this turn.
        context_id: The conversation id to echo.
        index: Position of this surface in the turn, from zero.
        intent: The registered view the client is asked to render.

    Returns:
        The event body the client may render before the answer arrives.
    """
    return {
        "kind": "render-intent",
        "taskId": task_id,
        "contextId": context_id,
        "index": index,
        "renderIntent": intent.model_dump(mode="json"),
    }


def answer(
    task_id: str,
    context_id: str | None,
    text: str,
    intents: tuple[RenderIntent, ...],
    suggestions: tuple[str, ...] = (),
) -> dict[str, object]:
    """Build the terminal message event carrying the answer and every surface.

    Args:
        task_id: Correlation id of this turn.
        context_id: The conversation id to echo.
        text: The assistant's answer.
        intents: Every render intent of the turn, in order.
        suggestions: Keys the turn recommends next (spec 0029), sent with labels.

    Returns:
        The event body; ``renderIntents`` repeats the incremental events.
    """
    return {
        "kind": "message",
        "taskId": task_id,
        "contextId": context_id,
        "role": "agent",
        "parts": [{"kind": "text", "text": text}],
        "renderIntents": [intent.model_dump(mode="json") for intent in intents],
        "suggestions": suggestion_chips(suggestions),
    }


__all__ = [
    "COMPLETED",
    "FAILED",
    "INPUT_REQUIRED",
    "INTERNAL",
    "TURN_FAILED",
    "WORKING",
    "answer",
    "failed",
    "sse",
    "status",
    "surface",
]
