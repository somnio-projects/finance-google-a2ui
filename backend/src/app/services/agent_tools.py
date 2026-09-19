"""Running one tool call safely, on behalf of the turn loop (spec 0006 §3.4).

Split out of ``agent_service`` because it answers a different question: the
loop decides *when* to call a tool, this module decides what happens when the
call goes wrong. Neither an unknown tool nor a raising one fails the turn —
the model is told in a structured result and gets another iteration to
recover.

The exception's text goes to the ``ErrorReporter`` and nowhere else: the log
line carries the exception *type*, never its message, because a tool's message
can quote a value the portfolio holds.
"""

from collections.abc import Mapping
from typing import Final

import structlog

from app.agent.contracts import Tool, ToolContext, TurnState
from app.agent.registry import ToolRegistry
from app.core.logging import get_logger
from app.core.model import MessageRole, ModelMessage, ToolCall
from app.core.protocols import ErrorReporter

log: structlog.stdlib.BoundLogger = get_logger(__name__)

UNKNOWN_TOOL_ERROR: Final[Mapping[str, object]] = {"error": "unknown-tool"}
TOOL_FAILED_ERROR: Final[Mapping[str, object]] = {"error": "tool-failed"}


def tool_message(call: ToolCall, result: Mapping[str, object]) -> ModelMessage:
    """Wrap a tool's payload as the message the model reads next.

    Args:
        call: The call this message answers.
        result: The JSON-serialisable payload, or an error marker.

    Returns:
        A ``role=tool`` message correlated by ``call_id``.
    """
    return ModelMessage(
        role=MessageRole.TOOL,
        tool_call_id=call.call_id,
        tool_name=call.name,
        tool_result=result,
    )


async def execute_tool(
    call: ToolCall,
    context: ToolContext,
    *,
    tools: ToolRegistry,
    reporter: ErrorReporter,
    state: TurnState,
) -> ModelMessage:
    """Run one requested tool and render its outcome as a tool message.

    Args:
        call: What the model asked for, unvalidated.
        context: The subject and portfolio provider the tool may reach.
        tools: The registry the call is resolved against.
        reporter: Where a raising tool's exception is reported.
        state: The turn's accumulator; a render intent is appended to it.

    Returns:
        The tool message to feed back — the tool's payload on success, or a
        structured error the model can recover from.
    """
    tool: Tool | None = tools.get(call.name)
    if tool is None:
        log.warning("agent.tool.unknown", tool=call.name)
        return tool_message(call, UNKNOWN_TOOL_ERROR)
    try:
        outcome = await tool.run(call.arguments, context)
    except Exception as exc:
        reporter.capture_exception(exc)
        log.warning("agent.tool.failed", tool=call.name, error=type(exc).__name__)
        return tool_message(call, TOOL_FAILED_ERROR)
    if outcome.render is not None:
        state.renders.append(outcome.render)
    return tool_message(call, outcome.data)


__all__ = ["TOOL_FAILED_ERROR", "UNKNOWN_TOOL_ERROR", "execute_tool", "tool_message"]
