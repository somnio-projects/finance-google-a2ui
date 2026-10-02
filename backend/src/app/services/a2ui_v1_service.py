"""One call on ``POST /a2ui/v1/a2a``, routed to what answers it (ADR-M D-2).

Three things can arrive, and each goes to the piece that already owns it:

* **prose** → a turn, through the agent loop (``V1TurnStream``);
* **``callAgentFunction``** → ``RenderViewService``, with no model at all;
* **``action``** → ``SurfaceActionService`` composes the prompt, then a turn.

Everything a client can get wrong is refused **before** the stream opens, as a
JSON-RPC error body; once a stream opens, a failure is the terminal pair
inside it. That is the v0.9 contract (spec 0022 AC-4), unchanged.
"""

from collections.abc import AsyncIterator

from app.agent.contracts import ToolContext
from app.core.principal import Principal
from app.core.protocols import ErrorReporter
from app.presentation.a2ui_v1.messages import data_part
from app.schemas.a2ui_v1_events import CallAgentFunction, FunctionMessage
from app.services.a2a_dispatch import parse
from app.services.a2a_events import COMPLETED, sse, status
from app.services.a2ui_v1_actions import action_prompt
from app.services.a2ui_v1_dispatch import v1_message_of
from app.services.a2ui_v1_events import artifact, guarded
from app.services.a2ui_v1_render_view import RenderViewService
from app.services.a2ui_v1_turn import V1TurnStream
from app.services.surface_action_service import SurfaceActionService

#: What the route answers: an event stream, or a JSON-RPC error body.
Outcome = AsyncIterator[str] | dict[str, object]


class A2uiV1Service:
    """The v1.0 protocol adapter: parse, negotiate, route."""

    def __init__(
        self,
        *,
        turns: V1TurnStream,
        functions: RenderViewService,
        actions: SurfaceActionService,
        reporter: ErrorReporter,
    ) -> None:
        """Bind the adapter to the three things that answer a call."""
        self._turns = turns
        self._functions = functions
        self._actions = actions
        self._reporter = reporter

    async def call(
        self,
        body: object,
        *,
        principal: Principal,
        context: ToolContext,
        task_id: str,
        request_id: str,
    ) -> Outcome:
        """Answer one decoded request body.

        Args:
            body: The JSON body, of whatever shape arrived.
            principal: The authenticated caller.
            context: The subject-scoped tool context.
            task_id: Correlation id for this call.
            request_id: Correlation id, for an audited action's event.

        Returns:
            The event stream, or the JSON-RPC error body to answer at 200.
        """
        envelope = parse(body)
        if isinstance(envelope, dict):
            return envelope
        message = v1_message_of(envelope)
        if isinstance(message, dict):
            return message
        context_id = message.context_id
        incoming = message.renderer_message()
        if incoming is None:
            prompt: str | dict[str, object] = message.text()
        elif isinstance(incoming, FunctionMessage):
            call = incoming.call_agent_function
            return self._function(call, task_id=task_id, context_id=context_id)
        else:
            prompt = await action_prompt(
                self._actions,
                principal=principal,
                event=incoming.action,
                rpc_id=envelope.id,
                request_id=request_id,
            )
        if isinstance(prompt, dict):
            return prompt
        return self._turns.stream(
            prompt=prompt, task_id=task_id, context_id=context_id, context=context
        )

    def _function(
        self, call: CallAgentFunction, *, task_id: str, context_id: str | None
    ) -> AsyncIterator[str]:
        """Stream a function call's answer: one artifact, then ``completed``."""
        return guarded(
            task_id,
            context_id,
            self._answer(call, task_id, context_id),
            reporter=self._reporter,
        )

    async def _answer(
        self, call: CallAgentFunction, task_id: str, context_id: str | None
    ) -> AsyncIterator[str]:
        """Yield the function's answer and close the task."""
        messages = await self._functions.answer(call)
        artifact_id = f"{call.surface_id}-{call.function_call_id}"
        yield sse(artifact(task_id, context_id, artifact_id, data_part(messages)))
        yield sse(status(task_id, context_id, COMPLETED))


__all__ = ["A2uiV1Service", "Outcome"]
