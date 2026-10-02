"""The A2A events a v1.0 turn emits that a v0.9 turn does not (ADR-M D-3).

The status events and the failure pair are v0.9's own, from
``a2a_events`` — the task lifecycle did not change. What changed is how a
surface travels: as an ``artifact-update`` whose artifact is one A2UI
``DataPart``, and a terminal ``message`` that no longer repeats the surfaces
(``renderIntents`` is a v0.9 field and stays there).

``guarded`` is the stream's safety net, shared by a turn and a function call:
by the time anything can fail the client has a 200, so a failure is reported
inside the stream as the terminal pair, never as a truncated response.
"""

from collections.abc import AsyncIterator, Mapping
from typing import Any

from app.actions.suggestions import suggestion_chips
from app.core.errors import AppError
from app.core.protocols import ErrorReporter
from app.services.a2a_events import INTERNAL, TURN_FAILED, WORKING, failed, sse, status


def artifact(
    task_id: str, context_id: str | None, artifact_id: str, part: Mapping[str, Any]
) -> dict[str, object]:
    """Build the event that carries one A2UI ``DataPart``.

    Args:
        task_id: Correlation id of this call.
        context_id: The conversation id to echo.
        artifact_id: The surface id, or ``<surfaceId>-<functionCallId>`` for a
            function's answer.
        part: The ``DataPart`` built by ``presentation.a2ui_v1.messages``.
    """
    return {
        "kind": "artifact-update",
        "taskId": task_id,
        "contextId": context_id,
        "artifact": {"artifactId": artifact_id, "parts": [dict(part)]},
    }


def closing(
    task_id: str, context_id: str | None, text: str, suggestions: tuple[str, ...]
) -> dict[str, object]:
    """Build the terminal message: the answer and the chips, no surfaces (D-3)."""
    return {
        "kind": "message",
        "taskId": task_id,
        "contextId": context_id,
        "role": "agent",
        "parts": [{"kind": "text", "text": text}],
        "suggestions": suggestion_chips(suggestions),
    }


async def guarded(
    task_id: str,
    context_id: str | None,
    inner: AsyncIterator[str],
    *,
    reporter: ErrorReporter,
) -> AsyncIterator[str]:
    """Open with ``working``, forward ``inner``, and end cleanly if it fails.

    Args:
        task_id: Correlation id of this call.
        context_id: The conversation id to echo.
        inner: The events of the call, already framed as SSE.
        reporter: Where an unexpected failure is captured.

    Yields:
        The opening status, every event of ``inner``, and — when ``inner``
        raised — the ``failed`` status with a safe error event instead of a
        stream that stops mid-sentence.
    """
    yield sse(status(task_id, context_id, WORKING))
    try:
        async for event in inner:
            yield event
    except AppError as exc:
        for event in failed(task_id, context_id, exc.code, exc.detail):
            yield sse(event)
    except Exception as exc:
        # Reporting, not swallowing. A failure inside the turn loop was
        # already captured there; capturing the same exception object again
        # is collapsed by the reporter's de-duplication, while a defect in the
        # v1.0 rendering itself would otherwise reach nobody.
        reporter.capture_exception(exc)
        for event in failed(task_id, context_id, INTERNAL, TURN_FAILED):
            yield sse(event)


__all__ = ["artifact", "closing", "guarded"]
