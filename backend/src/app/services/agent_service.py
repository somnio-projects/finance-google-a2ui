"""The turn's boundary: history in, events out, one metric recorded.

One turn is a bounded conversation with the model (spec 0006 §3.3). The
model/tool loop itself lives next door in ``app.services.agent_loop``; this
module owns what surrounds it — the history the turn starts from, the single
metric and log line it records, and the failure it reports.

**Two entry points, one loop.** ``run_turn_events`` is the real one: it yields
each surface the moment it is ready, which is what ADR-K D-19 asks for and
what the A2A adapter streams. ``run_turn`` is a thin collector kept for every
caller that just wants the finished turn, so nothing had to move when the loop
learned to yield.

**Sessions are not here.** Both entry points take the history as an argument
and hold no state between turns; this module imports no session module.

**What is logged.** Exactly one metric and one log line per turn: the model,
the outcome, the latency and the counters — never the prompt, the reply, tool
arguments, tool results or the subject (spec 0006 §5, AC-13).
"""

from collections.abc import AsyncIterator, Sequence
from datetime import datetime

from app.agent.contracts import ToolContext, TurnResult, TurnState
from app.agent.events import TurnCompleted, TurnEvent
from app.agent.registry import ToolRegistry
from app.core.errors import DependencyUnavailableError
from app.core.model import MessageRole, ModelMessage
from app.core.protocols import Clock, ErrorReporter, ModelClient
from app.services.agent_loop import TurnLoop
from app.services.agent_telemetry import TURN_METRIC, record_turn


class AgentService:
    """Run one agent turn against a model and the registered tools."""

    def __init__(
        self,
        *,
        model: ModelClient,
        tools: ToolRegistry,
        reporter: ErrorReporter,
        clock: Clock,
        max_iterations: int,
        system_prompt: str,
    ) -> None:
        """Inject the collaborators, the bound and the already-built prompt.

        The prompt arrives built because it carries catalogues generated from
        both registries (GGU-14), which this package cannot reach on its own.
        """
        self._loop = TurnLoop(
            model=model,
            tools=tools,
            reporter=reporter,
            system_prompt=system_prompt,
            max_iterations=max_iterations,
        )
        self._model_name = model.name
        self._reporter = reporter
        self._clock = clock

    async def run_turn_events(
        self,
        *,
        prompt: str,
        history: Sequence[ModelMessage],
        context: ToolContext,
    ) -> AsyncIterator[TurnEvent]:
        """Answer ``prompt``, yielding each surface as soon as it is ready.

        Args:
            prompt: What the user just asked.
            history: The conversation before this turn, oldest first.
            context: The subject and portfolio provider handed to every tool.

        Yields:
            One ``SurfaceReady`` per render intent, in production order, then
            exactly one ``TurnCompleted`` carrying the answer and the counters.

        Raises:
            DependencyUnavailableError: When the model provider failed.
            Exception: Anything else a collaborator raised. Every failure
                is reported and counted **here** before it is re-raised: the
                transport above may already have sent a 200, leaving it able
                only to emit a terminal event, never to report.
        """
        started = self._clock.now()
        state = TurnState()
        messages = [*history, ModelMessage(role=MessageRole.USER, text=prompt)]
        try:
            async for event in self._loop.run(messages, context, state):
                yield event
        except DependencyUnavailableError as exc:
            self._record(started, state, outcome="model-unavailable", failure=exc)
            raise
        except Exception as exc:
            self._record(started, state, outcome="error", failure=exc)
            raise
        self._record(started, state, outcome="ok")

    async def run_turn(
        self,
        *,
        prompt: str,
        history: Sequence[ModelMessage],
        context: ToolContext,
    ) -> TurnResult:
        """Run a turn and return only its finished result.

        Args:
            prompt: What the user just asked.
            history: The conversation before this turn, oldest first.
            context: The subject and portfolio provider handed to every tool.

        Returns:
            The answer, the render intents and the counters. The surfaces
            are still emitted in order; this waits for the last event.
        """
        finished = [
            event.result
            async for event in self.run_turn_events(
                prompt=prompt, history=history, context=context
            )
            if isinstance(event, TurnCompleted)
        ]
        return finished[-1]

    def _record(
        self,
        started: datetime,
        state: TurnState,
        *,
        outcome: str,
        failure: BaseException | None = None,
    ) -> None:
        """Hand the turn's counters — and any failure — to the telemetry boundary."""
        if failure is not None:
            self._reporter.capture_exception(failure)
        record_turn(
            self._reporter,
            state,
            model=self._model_name,
            outcome=outcome,
            elapsed=self._clock.now() - started,
        )


__all__ = ["TURN_METRIC", "AgentService"]
