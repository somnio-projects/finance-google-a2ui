"""Translate an A2A call into a turn, and a turn into protocol events.

This is the **thin adapter** ADR-J D-2 requires: it knows the protocol envelope
and nothing else. No business rule lives here, and `AgentService` does not know
the protocol exists — which is what lets A2A move (it is alpha) without the
services moving with it. The event shapes themselves live in
`app.services.a2a_events`.

**The stream is incremental** (ADR-K D-19, ADR-D). `AgentService.run_turn_events`
yields each render intent the moment the tool that produced it returned, so
this adapter forwards a `render-intent` event per surface *while the turn is
still running*, and only then the terminal `message` and status. Perceived
latency is therefore the time to the first widget, not to the last. The
terminal message still carries the full `renderIntents` list, so a client that
ignores the incremental events sees exactly what spec 0010 AC-2 documented.

**What this still does not do, stated plainly:** *conversation history*.
`contextId` is echoed for correlation but no history is loaded, because
sessions (GGU-46) are not on this branch. Every turn starts empty. The
resolution rule is already decided (ADR-J D-4, ADR-A): a `contextId` is
resolved **against the authenticated subject** or treated as unknown, never
trusted on its own.
"""

from collections.abc import AsyncIterator

from app.agent.contracts import ToolContext, TurnResult
from app.agent.events import SurfaceReady
from app.core.errors import AppError
from app.schemas.a2a import ClientMessage
from app.services.a2a_events import (
    COMPLETED,
    FAILED,
    INPUT_REQUIRED,
    INTERNAL,
    TURN_FAILED,
    WORKING,
    answer,
    failed,
    sse,
    status,
    surface,
)
from app.services.agent_service import AgentService


class A2aService:
    """Run one A2A call as a turn, and emit its events.

    Deciding *what* was asked is `a2a_dispatch`; this runs it and reports.
    """

    def __init__(self, *, agent: AgentService) -> None:
        """Bind the adapter to the agent host it delegates to."""
        self._agent = agent

    async def stream(
        self,
        *,
        message: ClientMessage,
        prompt: str,
        task_id: str,
        context: ToolContext,
    ) -> AsyncIterator[str]:
        """Yield the events of one turn, in protocol order.

        Args:
            message: The client's message, already validated.
            prompt: The turn's input, from ``prepared_prompt`` — the prose a
                person typed, or the sentence the backend composed for an action.
            task_id: Correlation id for this turn.
            context: The subject-scoped tool context.

        Yields:
            Server-sent events: a `working` status, a `render-intent` per
            surface as it becomes ready, then either the answer and a terminal
            status, or a terminal `failed` status. A failure is reported
            **inside the stream** rather than as a transport error, because the
            client has already received a 200 and a header by the time a turn
            can fail.
        """
        yield sse(status(task_id, message.context_id, WORKING))
        try:
            async for event in self._turn(message, prompt, task_id, context):
                yield event
        except AppError as exc:
            for event in failed(task_id, message.context_id, exc.code, exc.detail):
                yield sse(event)
        except Exception:
            # The response has already started, so a raise here reaches the
            # 500 handler with no body left to send: the client would get a
            # truncated stream whose last state is `working` and no terminal
            # event. Catching everything and emitting the terminal pair is
            # reporting, not swallowing — the exception still goes to the
            # reporter through the turn loop that raised it.
            for event in failed(task_id, message.context_id, INTERNAL, TURN_FAILED):
                yield sse(event)

    async def _turn(
        self,
        message: ClientMessage,
        prompt: str,
        task_id: str,
        context: ToolContext,
    ) -> AsyncIterator[str]:
        """Forward the turn's own events, surfaces first, terminal pair last."""
        context_id = message.context_id
        results: list[TurnResult] = []
        async for event in self._agent.run_turn_events(
            prompt=prompt, history=[], context=context
        ):
            if isinstance(event, SurfaceReady):
                yield sse(surface(task_id, context_id, event.index, event.intent))
            else:
                results.append(event.result)
        result = results[-1]
        yield sse(answer(task_id, context_id, result.message, result.render_intents))
        terminal = INPUT_REQUIRED if result.render_intents else COMPLETED
        yield sse(status(task_id, context_id, terminal))


__all__ = [
    "COMPLETED",
    "FAILED",
    "INPUT_REQUIRED",
    "TURN_FAILED",
    "WORKING",
    "A2aService",
    "sse",
]
