"""A turn whose one tool call was decided before it started (spec 0056).

A surface action may pin the tool it runs — ``drill.attribution.v1`` names the
only argument ``driver_detail`` takes. Such a turn has nothing left for a model
to decide, so it asks none: the call goes through the **same**
``execute_tool`` a model's call would (argument validation, the registry's
verdict on the render intent, failure reporting), its surface leaves the
moment it exists, and the turn completes with the action's own narration.

Why not hand the model a pre-filled call and let it narrate: Gemini 3 refuses
a ``functionCall`` with no ``thoughtSignature``, and that signature is
provider state this service must never invent (GGU-88, 0056 OD-1).
"""

from collections.abc import AsyncIterator

from app.actions.contracts import DirectCall
from app.agent.contracts import ToolContext, TurnResult, TurnState
from app.agent.events import SurfaceReady, TurnCompleted, TurnEvent
from app.agent.registry import ToolRegistry
from app.core.model import ToolCall
from app.core.protocols import ErrorReporter
from app.services.agent_renders import TurnRenderResolver
from app.services.agent_tools import execute_tool


async def direct_turn(
    direct: DirectCall,
    context: ToolContext,
    state: TurnState,
    *,
    tools: ToolRegistry,
    reporter: ErrorReporter,
    renders: TurnRenderResolver,
) -> AsyncIterator[TurnEvent]:
    """Run the pinned call, emit its surface and complete — no model call.

    Args:
        direct: The tool, its validated arguments and the narration.
        context: The subject and portfolio provider handed to the tool.
        state: The turn's accumulator; ``iterations`` stays at zero.
        tools: The registry the call is resolved against.
        reporter: Where a raising tool's exception is reported.
        renders: The projection registry's verdict on the tool's intent.

    Yields:
        One ``SurfaceReady`` per render intent the tool produced, then
        exactly one ``TurnCompleted`` carrying the narration.
    """
    call = ToolCall(
        call_id=f"direct-{direct.tool}", name=direct.tool, arguments=direct.arguments
    )
    state.tool_calls += 1
    message = await execute_tool(
        call, context, tools=tools, reporter=reporter, renders=renders, state=state
    )
    for index, intent in state.take_renders():
        yield SurfaceReady(index=index, intent=intent)
    answer = direct.answer(message.tool_result or {})
    yield TurnCompleted(
        TurnResult(
            message=answer,
            render_intents=tuple(state.renders),
            tool_calls=state.tool_calls,
            iterations=state.iterations,
            truncated=False,
        )
    )


__all__ = ["direct_turn"]
