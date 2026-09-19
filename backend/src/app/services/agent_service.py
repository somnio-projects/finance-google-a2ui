"""The turn loop: prompt + history + tools → an answer and render intents.

One turn is a bounded conversation with the model (spec 0006 §3.3): assemble,
call, run whatever tools were asked for, feed the results back, repeat until
the model answers or the iteration bound stops it. What happens when a tool
misbehaves lives next door, in ``app.services.agent_tools``.

**Sessions are not here.** ``run_turn`` takes the history as an argument and
holds no state between turns; it imports no session module. GGU-46 owns where
a history comes from and GGU-3 how the answer streams — both wrap this call.

**What is logged.** Exactly one metric and one log line per turn: the model,
the outcome, the latency and the counters — never the prompt, the reply, tool
arguments, tool results or the subject (spec 0006 §5, AC-13).
"""

from collections.abc import Sequence
from datetime import datetime

from app.agent.contracts import ToolContext, TurnResult, TurnState
from app.agent.prompt import ITERATION_LIMIT_MESSAGE
from app.agent.registry import ToolRegistry
from app.core.errors import DependencyUnavailableError
from app.core.model import MessageRole, ModelMessage
from app.core.protocols import Clock, ErrorReporter, ModelClient
from app.services.agent_telemetry import TURN_METRIC, record_turn
from app.services.agent_tools import execute_tool


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
        self._model = model
        self._tools = tools
        self._system_prompt = system_prompt
        self._reporter = reporter
        self._clock = clock
        self._max_iterations = max_iterations

    async def run_turn(
        self,
        *,
        prompt: str,
        history: Sequence[ModelMessage],
        context: ToolContext,
    ) -> TurnResult:
        """Answer ``prompt`` given ``history``, calling tools as needed.

        Args:
            prompt: What the user just asked.
            history: The conversation before this turn, oldest first.
            context: The subject and portfolio provider handed to every tool.

        Returns:
            The answer, the render intents the tools produced and the counters.

        Raises:
            DependencyUnavailableError: When the model provider failed. It is
                reported first, then re-raised for the API layer to render as
                the standard 503 problem document.
        """
        started = self._clock.now()
        state = TurnState()
        messages = [*history, ModelMessage(role=MessageRole.USER, text=prompt)]
        try:
            result = await self._loop(messages, context, state)
        except DependencyUnavailableError as exc:
            self._reporter.capture_exception(exc)
            self._record(started, state, outcome="model-unavailable")
            raise
        self._record(started, state, outcome="ok")
        return result

    async def _loop(
        self,
        messages: list[ModelMessage],
        context: ToolContext,
        state: TurnState,
    ) -> TurnResult:
        """Call the model until it answers or the iteration bound is reached."""
        while state.iterations < self._max_iterations:
            state.iterations += 1
            reply = await self._model.generate(
                system=self._system_prompt,
                messages=messages,
                tools=self._tools.specs(),
            )
            if not reply.tool_calls:
                return self._result(state, message=reply.text, truncated=False)
            messages.append(
                ModelMessage(
                    role=MessageRole.ASSISTANT,
                    text=reply.text,
                    tool_calls=reply.tool_calls,
                )
            )
            for call in reply.tool_calls:
                state.tool_calls += 1
                message = await execute_tool(
                    call,
                    context,
                    tools=self._tools,
                    reporter=self._reporter,
                    state=state,
                )
                messages.append(message)
        return self._result(state, message=ITERATION_LIMIT_MESSAGE, truncated=True)

    @staticmethod
    def _result(state: TurnState, *, message: str, truncated: bool) -> TurnResult:
        """Freeze the accumulated state into the turn's result."""
        return TurnResult(
            message=message,
            render_intents=tuple(state.renders),
            tool_calls=state.tool_calls,
            iterations=state.iterations,
            truncated=truncated,
        )

    def _record(self, started: datetime, state: TurnState, *, outcome: str) -> None:
        """Hand the turn's counters to the telemetry boundary."""
        record_turn(
            self._reporter,
            state,
            model=self._model.name,
            outcome=outcome,
            elapsed=self._clock.now() - started,
        )


__all__ = ["TURN_METRIC", "AgentService"]
