"""The client message of a v1.0 ``message/stream`` call (ADR-M D-6…D-8).

Beside ``a2a_message`` rather than inside it: that model is the v0.9 contract,
and nothing about it may move (ADR-M D-2). The shape here differs in exactly
the places v1.0 does — the data part carries A2UI messages under a MIME type
instead of an action id, and the message carries the renderer's capabilities
in its ``metadata`` (ADR-M D-8).

The one-kind rule is the v0.9 one, for the v0.9 reason (spec 0022 AC-5): a
surface either sends a message or a person types a sentence.
"""

from typing import Annotated, Literal, Self

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

from app.presentation.a2ui_v1.wire import MIME_TYPE
from app.schemas.a2a_parts import TextPart
from app.schemas.a2ui_v1_capabilities import MessageMetadata
from app.schemas.a2ui_v1_events import RendererMessage


class PartMetadata(BaseModel):
    """What marks a data part as A2UI."""

    model_config = ConfigDict(frozen=True, extra="ignore", populate_by_name=True)

    mime_type: Literal["application/a2ui+json"] = Field(
        alias="mimeType", description="Always `application/a2ui+json`."
    )


class A2uiDataPart(BaseModel):
    """An A2A ``DataPart`` carrying one renderer-to-agent v1.0 message."""

    model_config = ConfigDict(frozen=True, extra="ignore")

    kind: Literal["data"] = Field(description="Part discriminator.")
    metadata: PartMetadata = Field(description=f"`{{mimeType: {MIME_TYPE}}}`.")
    data: tuple[RendererMessage, ...] = Field(
        min_length=1,
        max_length=1,
        description="Exactly one message: an action or a function call.",
    )


#: An id the renderer chose and the agent only echoes; bounded because it is
#: reflected verbatim.
CorrelationId = Annotated[str | None, StringConstraints(max_length=128)]


class V1ClientMessage(BaseModel):
    """The message a v1.0 renderer sends in a ``message/stream`` call."""

    model_config = ConfigDict(frozen=True, extra="ignore", populate_by_name=True)

    role: Literal["user"] = Field(default="user", description="Always `user`.")
    parts: tuple[TextPart | A2uiDataPart, ...] = Field(
        min_length=1, max_length=16, description="Prose, or one A2UI data part."
    )
    message_id: CorrelationId = Field(
        None, alias="messageId", description="Renderer-generated id, echoed back."
    )
    context_id: CorrelationId = Field(
        None,
        alias="contextId",
        description="Echoed for correlation; never trusted on its own (ADR-J D-4).",
    )
    metadata: MessageMetadata = Field(
        default_factory=MessageMetadata, description="Renderer capabilities."
    )

    @model_validator(mode="after")
    def _one_kind_of_part(self) -> Self:
        """Refuse a data part beside prose, or two data parts (spec 0022 AC-5).

        Raises:
            ValueError: When the message mixes kinds or carries two data parts.
        """
        data = [part for part in self.parts if isinstance(part, A2uiDataPart)]
        if data and len(self.parts) != 1:
            msg = "a message carrying a data part carries nothing else"
            raise ValueError(msg)
        return self

    def text(self) -> str:
        """Return the text parts joined into one prompt."""
        return " ".join(
            part.text for part in self.parts if isinstance(part, TextPart)
        ).strip()

    def renderer_message(self) -> RendererMessage | None:
        """Return the A2UI message this carries, or ``None`` for prose."""
        part = self.parts[0]
        return part.data[0] if isinstance(part, A2uiDataPart) else None

    def catalogs(self) -> tuple[str, ...]:
        """Return the catalog ids the renderer declared for v1.0, if any."""
        return self.metadata.catalogs()


class V1StreamParams(BaseModel):
    """Parameters of a v1.0 ``message/stream``."""

    model_config = ConfigDict(frozen=True, extra="ignore")

    message: V1ClientMessage = Field(description="What the renderer sent.")


__all__ = [
    "A2uiDataPart",
    "PartMetadata",
    "V1ClientMessage",
    "V1StreamParams",
]
