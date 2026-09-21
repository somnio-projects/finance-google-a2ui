"""The client message of a `message/stream` call, and the parts it may carry.

Split from ``a2a.py`` under the 150-line budget when GGU-78 gave the envelope
a second part kind. ``a2a.py`` re-exports everything here, so a caller still
imports the whole protocol vocabulary from one place — the same arrangement
``presentation.fragments`` has with ``presentation.displays``.

The validator is the interesting part. A surface either sends **an action** or
a person types **a sentence**; a message carrying both would leave "what did
the client actually ask for?" to a precedence rule nobody wrote down, so it is
a rejection instead (spec 0022 AC-5).
"""

from typing import Literal, Self

from pydantic import BaseModel, ConfigDict, Field, model_validator

from app.schemas.a2a_parts import ActionData, DataPart, MessagePart, TextPart


class ClientMessage(BaseModel):
    """The message the client sends in a `message/stream` call."""

    model_config = ConfigDict(frozen=True, extra="ignore")

    role: Literal["user"] = Field(default="user", description="Always `user`.")
    parts: tuple[MessagePart, ...] = Field(
        min_length=1, max_length=16, description="Message parts, in order."
    )
    message_id: str | None = Field(
        default=None,
        alias="messageId",
        max_length=128,
        description="Client-generated id, echoed back for correlation.",
    )
    context_id: str | None = Field(
        default=None,
        alias="contextId",
        max_length=128,
        description=(
            "Conversation the client believes this belongs to. **Never trusted "
            "on its own** — it is resolved against the authenticated subject, "
            "or treated as unknown (ADR-J D-4, ADR-A)."
        ),
    )

    @model_validator(mode="after")
    def _one_kind_of_part(self) -> Self:
        """Refuse a message that mixes an action with prose (0022 AC-5).

        A surface either sends an action or a person types a sentence. A
        message carrying both leaves "what did the client actually ask for?"
        to a precedence rule nobody wrote down, so it is a rejection instead.

        Raises:
            ValueError: When more than one `data` part is present, or when a
                `data` part arrives alongside a `text` part.
        """
        actions = [part for part in self.parts if isinstance(part, DataPart)]
        if len(actions) > 1:
            msg = "a message carries at most one data part"
            raise ValueError(msg)
        if actions and len(actions) != len(self.parts):
            msg = "a message carrying a data part carries no text part"
            raise ValueError(msg)
        return self

    def text(self) -> str:
        """Return the message's text parts joined into one prompt."""
        return " ".join(
            part.text for part in self.parts if isinstance(part, TextPart)
        ).strip()

    def action(self) -> ActionData | None:
        """Return the action this message sends back, or ``None`` for prose."""
        for part in self.parts:
            if isinstance(part, DataPart):
                return part.data
        return None


class StreamParams(BaseModel):
    """Parameters of `message/stream`."""

    model_config = ConfigDict(frozen=True, extra="ignore")

    message: ClientMessage = Field(description="What the user sent.")


__all__ = ["ClientMessage", "StreamParams"]
