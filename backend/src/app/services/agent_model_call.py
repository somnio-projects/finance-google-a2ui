"""One model call inside a turn, and what it cost (spec 0058 AC-4).

Split out of ``agent_loop`` because the loop sits at the 150-line ceiling and
this is the one place the turn learns what it spent. A call's usage is added
to the turn **whether it succeeded or not**: a failed call's attempts may
still have been billed, and a turn that fails on its third model call paid
for the first two — the failure is re-raised unchanged after the sum.
"""

from collections.abc import Sequence

from app.agent.contracts import TurnState
from app.core.model import ModelMessage, ModelReply, ToolSpec
from app.core.model_errors import ModelProviderError
from app.core.protocols import ModelClient


async def ask_model(
    model: ModelClient,
    state: TurnState,
    *,
    system: str,
    messages: Sequence[ModelMessage],
    tools: Sequence[ToolSpec],
) -> ModelReply:
    """Call ``model`` once and add what the call billed to ``state.usage``.

    Args:
        model: The client the turn runs against.
        state: The turn's accumulator; its ``usage`` grows by this call's.
        system: The system instruction.
        messages: The conversation so far.
        tools: The tools offered this call.

    Returns:
        The model's reply, unchanged.

    Raises:
        ModelProviderError: Re-raised after its usage is counted.
    """
    try:
        reply = await model.generate(system=system, messages=messages, tools=tools)
    except ModelProviderError as exc:
        state.usage += exc.usage
        raise
    state.usage += reply.usage
    return reply


__all__ = ["ask_model"]
