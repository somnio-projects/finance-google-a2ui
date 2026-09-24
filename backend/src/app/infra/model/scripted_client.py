"""The ``ModelClient`` a stack without a provider key runs (spec 0033).

Until this module, an unset ``GEMINI_API_KEY`` meant ``NullModelClient``, whose
one sentence is that the service is up — honest, and the Assistant tab then
showed nothing but that sentence, while every tool the demo's flows need was
already deterministic. This client replays those flows from a table: a known
prompt runs its scripted tool calls, and once the loop has fed the results
back, the table's sentence is said with the tools' own strings in its holes.

**It is a model that cannot invent.** It picks tool calls from a fixed table
(ADR-K D-12), copies figures the tools returned (spec 0006 AC-8), and answers
any prompt outside the table with the same sentence the null client gave. It
holds no state between calls: the whole conversation arrives every time, and
the last user message is what it reads (spec 0006 §3.1).
"""

from collections.abc import Mapping, Sequence
from typing import Final

from app.core.model import MessageRole, ModelMessage, ModelReply, ToolCall, ToolSpec
from app.infra.model.demo_script import DEMO_SCRIPTS
from app.infra.model.null_client import UNCONFIGURED_MESSAGE, RecordedCall
from app.infra.model.script import Script, fill, normalise

MODEL_NAME: Final[str] = "scripted"


def _last_question(
    messages: Sequence[ModelMessage],
) -> tuple[str | None, tuple[Mapping[str, object], ...]]:
    """Return the last user message and the tool results that followed it.

    Args:
        messages: The whole conversation, oldest first.

    Returns:
        The prompt this turn answers — ``None`` when nobody has asked
        anything — and every tool result the loop appended after it, which
        is empty on the turn's first call and non-empty on its second.
    """
    for index in range(len(messages) - 1, -1, -1):
        if messages[index].role is MessageRole.USER:
            results = tuple(
                message.tool_result
                for message in messages[index + 1 :]
                if message.tool_result is not None
            )
            return messages[index].text, results
    return None, ()


def _tool_calls(script: Script) -> tuple[ToolCall, ...]:
    """Render the script's calls as the model would have asked for them."""
    return tuple(
        ToolCall(
            call_id=f"{index}-{call.name}", name=call.name, arguments=call.arguments
        )
        for index, call in enumerate(script.calls)
    )


class ScriptedModelClient:
    """Replay the demo's flows from a table of prompts; invent nothing."""

    def __init__(self, scripts: Mapping[str, Script] | None = None) -> None:
        """Bind the client to a table of normalised prompts.

        Args:
            scripts: Normalised prompt → script. ``None`` means the demo's
                own table; tests hand in a smaller one.
        """
        self._scripts = DEMO_SCRIPTS if scripts is None else scripts
        self.calls: list[RecordedCall] = []

    @property
    def name(self) -> str:
        """Model identifier reported to telemetry."""
        return MODEL_NAME

    async def generate(
        self,
        *,
        system: str,
        messages: Sequence[ModelMessage],
        tools: Sequence[ToolSpec],
    ) -> ModelReply:
        """Return the next scripted step for the conversation's last question.

        Args:
            system: The system instruction, recorded and otherwise unused.
            messages: The conversation so far, recorded and read.
            tools: The offered tools, recorded; the table names its own.

        Returns:
            The script's tool calls when its results are not yet in the
            conversation, its filled sentence when they are, and the
            unconfigured sentence for a prompt the table does not know.
        """
        self.calls.append(
            RecordedCall(system=system, messages=tuple(messages), tools=tuple(tools))
        )
        prompt, results = _last_question(messages)
        script = None if prompt is None else self._scripts.get(normalise(prompt))
        if script is None:
            return ModelReply(text=UNCONFIGURED_MESSAGE)
        if not results:
            return ModelReply(tool_calls=_tool_calls(script))
        return ModelReply(text=fill(script.answer, results, fallback=script.otherwise))


__all__ = ["MODEL_NAME", "ScriptedModelClient"]
