"""The model/tool loop of one turn, as a stream of events (ADR-K D-19).

Split out of ``app.services.agent_service`` when the loop learned to yield.
The two now answer different questions: this module decides *what happens
next* inside a turn, while ``AgentService`` owns the turn's boundary — the
history it starts from, the telemetry it records and the failure it reports.

The loop is an **async generator**, which is the whole point: a surface leaves
it the instant the tool that produced it returned, instead of waiting for the
model to finish talking. ``TurnCompleted`` is always the last thing it yields
on a path that does not raise.
"""

from collections.abc import AsyncIterator, Sequence

from app.agent.contracts import ToolContext, TurnResult, TurnState
from app.agent.events import SurfaceReady, TurnCompleted, TurnEvent
from app.agent.prompt import ITERATION_LIMIT_MESSAGE
from app.agent.registry import ToolRegistry
from app.core.model import MessageRole, ModelMessage, ToolCall
from app.core.protocols import ErrorReporter, ModelClient
from app.services.agent_renders import TurnRenderResolver
from app.services.agent_tools import execute_tool


def turn_result(state: TurnState, *, message: str, truncated: bool) -> TurnResult:
    """Freeze the accumulated state into the turn's result.

    Args:
        state: The counters and render intents the turn accumulated.
        message: The assistant's answer.
        truncated: True when the iteration bound ended the turn.

    Returns:
        The immutable result the caller of a turn receives.
    """
    return TurnResult(
        message=message,
        render_intents=tuple(state.renders),
        tool_calls=state.tool_calls,
        iterations=state.iterations,
        truncated=truncated,
    )


class TurnLoop:
    """Call the model until it answers, emitting each surface as it is ready."""

    def __init__(
        self,
        *,
        model: ModelClient,
        tools: ToolRegistry,
        reporter: ErrorReporter,
        renders: TurnRenderResolver,
        system_prompt: str,
        max_iterations: int,
    ) -> None:
        """Bind the loop to its collaborators, its prompt and its bound."""
        self._model = model
        self._tools = tools
        self._reporter = reporter
        self._renders = renders
        self._system_prompt = system_prompt
        self._max_iterations = max_iterations

    async def run(
        self,
        messages: list[ModelMessage],
        context: ToolContext,
        state: TurnState,
    ) -> AsyncIterator[TurnEvent]:
        """Yield the turn's events until the model answers or the bound stops it.

        Args:
            messages: The conversation so far; the loop appends to it.
            context: The subject and portfolio provider handed to every tool.
            state: The turn's accumulator, updated in place.

        Yields:
            One ``SurfaceReady`` per render intent as it is produced, then
            exactly one ``TurnCompleted``.

        Raises:
            DependencyUnavailableError: When the model provider failed. The
                turn's boundary reports and records it; the loop does not.
        """
        while state.iterations < self._max_iterations:
            state.iterations += 1
            reply = await self._model.generate(
                system=self._system_prompt,
                messages=messages,
                tools=self._tools.specs(),
            )
            if not reply.tool_calls:
                yield TurnCompleted(
                    turn_result(state, message=reply.text, truncated=False)
                )
                return
            messages.append(
                ModelMessage(
                    role=MessageRole.ASSISTANT,
                    text=reply.text,
                    tool_calls=reply.tool_calls,
                )
            )
            async for event in self._tool_round(
                reply.tool_calls, messages, context, state
            ):
                yield event
        yield TurnCompleted(
            turn_result(state, message=ITERATION_LIMIT_MESSAGE, truncated=True)
        )

    async def _tool_round(
        self,
        calls: Sequence[ToolCall],
        messages: list[ModelMessage],
        context: ToolContext,
        state: TurnState,
    ) -> AsyncIterator[TurnEvent]:
        """Run every tool the model asked for, emitting surfaces as they land."""
        for call in calls:
            state.tool_calls += 1
            messages.append(
                await execute_tool(
                    call,
                    context,
                    tools=self._tools,
                    reporter=self._reporter,
                    renders=self._renders,
                    state=state,
                )
            )
            for index, intent in state.take_renders():
                yield SurfaceReady(index=index, intent=intent)


__all__ = ["TurnLoop", "turn_result"]
