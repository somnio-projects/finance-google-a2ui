"""A turn, spoken in A2UI v1.0 (ADR-M D-2, D-3, D-4).

The loop is not copied. ``AgentService.run_turn_events`` already yields each
render intent the moment its tool returned, validated by the registry through
``RenderIntentService`` (GGU-84); the v0.9 adapter turns each one into a
``render-intent`` event. This adapter consumes the **same** events and differs
only in the last step: it renders the payload, composes it into a surface and
emits it as a ``createSurface`` inside an A2A ``artifact-update``.

Order is the loop's. A ticket is held only until the next view arrives, so a
payoff curve right after it joins its surface (D-4) and nothing is reordered.
"""

from collections.abc import AsyncIterator, Sequence
from typing import Final

from app.actions.suggestions import recommended
from app.agent.contracts import ToolContext, TurnResult
from app.agent.events import SurfaceReady
from app.core.protocols import ErrorReporter
from app.presentation.a2ui_v1.messages import data_part
from app.presentation.a2ui_v1.surfaces import (
    RenderedView,
    SurfaceComposer,
    surface_message,
)
from app.services.a2a_events import COMPLETED, INPUT_REQUIRED, sse, status
from app.services.a2ui_v1_events import artifact, closing, guarded
from app.services.a2ui_v1_payloads import PayloadRenderer
from app.services.agent_service import AgentService

#: Counted once per v1.0 turn, so the two wires can be told apart (spec 0053 §9).
WIRE_METRIC: Final[str] = "agent.turn.wire"
WIRE_TAGS: Final[dict[str, str]] = {"wire": "a2ui-v1.0"}


class V1TurnStream:
    """Run one turn and stream it as v1.0 surfaces."""

    def __init__(
        self,
        *,
        agent: AgentService,
        payloads: PayloadRenderer,
        reporter: ErrorReporter,
    ) -> None:
        """Bind the adapter to the agent host, the renderer and telemetry."""
        self._agent = agent
        self._payloads = payloads
        self._reporter = reporter

    def stream(
        self,
        *,
        prompt: str,
        task_id: str,
        context_id: str | None,
        context: ToolContext,
    ) -> AsyncIterator[str]:
        """Return the events of one turn, in protocol order.

        Args:
            prompt: The turn's input — the prose typed, or the sentence the
                backend composed for an action.
            task_id: Correlation id; surface ids are ``<task_id>-<index>``.
            context_id: The conversation id to echo.
            context: The subject-scoped tool context.

        Returns:
            ``working`` → one ``artifact-update`` per surface → the terminal
            ``message`` → a final status; or the failure pair.
        """
        self._reporter.increment(WIRE_METRIC, tags=WIRE_TAGS)
        inner = self._turn(prompt, task_id, context_id, context)
        return guarded(task_id, context_id, inner, reporter=self._reporter)

    async def _turn(
        self,
        prompt: str,
        task_id: str,
        context_id: str | None,
        context: ToolContext,
    ) -> AsyncIterator[str]:
        """Forward the loop's surfaces as they are drawn, then close the turn."""
        composer = SurfaceComposer()
        results: list[TurnResult] = []
        async for event in self._agent.run_turn_events(
            prompt=prompt, history=[], context=context
        ):
            if isinstance(event, SurfaceReady):
                rendered = await self._payloads.render(
                    index=event.index,
                    view=event.intent.view,
                    options=event.intent.options,
                )
                for group in composer.add(rendered):
                    yield self._surface(task_id, context_id, group)
            else:
                results.append(event.result)
        for group in composer.flush():
            yield self._surface(task_id, context_id, group)
        result = results[-1]
        yield sse(closing(task_id, context_id, result.message, recommended(prompt)))
        terminal = INPUT_REQUIRED if result.render_intents else COMPLETED
        yield sse(status(task_id, context_id, terminal))

    @staticmethod
    def _surface(
        task_id: str, context_id: str | None, group: Sequence[RenderedView]
    ) -> str:
        """Frame one composed surface as an ``artifact-update`` event."""
        message = surface_message(task_id, group)
        surface_id = str(message["createSurface"]["surfaceId"])
        return sse(artifact(task_id, context_id, surface_id, data_part([message])))


__all__ = ["WIRE_METRIC", "WIRE_TAGS", "V1TurnStream"]
