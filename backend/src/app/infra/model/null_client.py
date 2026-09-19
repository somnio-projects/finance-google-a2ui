"""Deterministic ``ModelClient`` used when no provider key is configured.

The same idea as ``NullErrorReporter``: call sites never ask "is a model
configured?" — they always call ``generate``, and this adapter makes that free
when there is no provider. The service therefore boots and answers with no
``GEMINI_API_KEY``, which is what keeps a demo from failing at startup over a
missing secret.

It performs no I/O at all. Tests script it with the replies a turn should see
and read ``calls`` back to assert what the loop actually sent — including that
tool results were fed back.
"""

from collections.abc import Sequence
from dataclasses import dataclass
from typing import Final

from app.core.model import ModelMessage, ModelReply, ToolSpec

UNCONFIGURED_MESSAGE: Final[str] = (
    "The assistant is running without a model provider, so it can only "
    "confirm that the service is up."
)


@dataclass(frozen=True, slots=True)
class RecordedCall:
    """One ``generate`` call, kept so tests can assert what was sent."""

    system: str
    messages: tuple[ModelMessage, ...]
    tools: tuple[ToolSpec, ...]


class NullModelClient:
    """Return scripted replies in order, repeating the last one forever."""

    def __init__(self, replies: Sequence[ModelReply] | None = None) -> None:
        """Script the client; the default is one fixed, tool-free answer.

        Args:
            replies: The replies to return, in order. An empty sequence is
                treated as "no script" and falls back to the default answer,
                so the client can never run out of things to say.
        """
        self._replies: tuple[ModelReply, ...] = tuple(replies or ()) or (
            ModelReply(text=UNCONFIGURED_MESSAGE),
        )
        self.calls: list[RecordedCall] = []

    @property
    def name(self) -> str:
        """Model identifier reported to telemetry."""
        return "null"

    async def generate(
        self,
        *,
        system: str,
        messages: Sequence[ModelMessage],
        tools: Sequence[ToolSpec],
    ) -> ModelReply:
        """Return the next scripted reply, recording the request.

        Args:
            system: The system instruction, recorded and otherwise unused.
            messages: The conversation so far, recorded.
            tools: The offered tools, recorded.

        Returns:
            The reply at the current position, or the last one once the
            script is exhausted.
        """
        self.calls.append(
            RecordedCall(system=system, messages=tuple(messages), tools=tuple(tools))
        )
        index = min(len(self.calls) - 1, len(self._replies) - 1)
        return self._replies[index]


__all__ = ["UNCONFIGURED_MESSAGE", "NullModelClient", "RecordedCall"]
