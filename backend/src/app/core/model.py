"""The model-agnostic conversation contract (spec 0006 §3.1).

These DTOs are what ``ModelClient`` speaks. They deliberately describe *our*
idea of a turn — a role, some text, tool calls, tool results — and not any
provider's wire format: mapping to Gemini's ``generateContent`` shape happens
in ``app.infra.model.payload`` and nowhere else, so a provider change is one
adapter, not a refactor of the turn loop.

Every model is frozen. A message that has been sent is history, and history
does not get edited in place.
"""

from collections.abc import Mapping
from enum import StrEnum
from typing import Final

from pydantic import BaseModel, ConfigDict, Field

TOOL_NAME_PATTERN: Final[str] = r"^[a-z][a-z0-9_]{2,47}$"


class MessageRole(StrEnum):
    """Who produced a message in the conversation."""

    USER = "user"
    ASSISTANT = "assistant"
    TOOL = "tool"


class ToolSpec(BaseModel):
    """What the model is told about one callable tool."""

    model_config = ConfigDict(frozen=True)

    name: str = Field(
        pattern=TOOL_NAME_PATTERN, description="Stable identifier the model calls."
    )
    description: str = Field(
        min_length=1,
        max_length=512,
        description="What the tool answers, in the model's own terms.",
    )
    parameters: Mapping[str, object] = Field(
        description="JSON Schema object describing the accepted arguments."
    )


class ToolCall(BaseModel):
    """One tool invocation the model asked for."""

    model_config = ConfigDict(frozen=True)

    call_id: str = Field(
        min_length=1, max_length=64, description="Correlates the call with its result."
    )
    name: str = Field(
        min_length=1, max_length=64, description="Tool the model asked for, as given."
    )
    arguments: Mapping[str, object] = Field(
        default_factory=dict, description="Raw arguments; validated by the tool."
    )


class ModelMessage(BaseModel):
    """One entry of the conversation handed to the model on every call."""

    model_config = ConfigDict(frozen=True)

    role: MessageRole = Field(description="Who produced this message.")
    text: str = Field(default="", description="Natural-language content, if any.")
    tool_calls: tuple[ToolCall, ...] = Field(
        default=(), description="Tool calls carried by an assistant message."
    )
    tool_call_id: str | None = Field(
        default=None, description="The ``call_id`` a tool message answers."
    )
    tool_name: str | None = Field(
        default=None, description="The tool a tool message comes from."
    )
    tool_result: Mapping[str, object] | None = Field(
        default=None, description="JSON-serialisable payload returned by the tool."
    )


class ModelReply(BaseModel):
    """What one ``generate`` call produced."""

    model_config = ConfigDict(frozen=True)

    text: str = Field(default="", description="The assistant's prose, possibly empty.")
    tool_calls: tuple[ToolCall, ...] = Field(
        default=(), description="Tools the model wants run before it can answer."
    )


__all__ = [
    "TOOL_NAME_PATTERN",
    "MessageRole",
    "ModelMessage",
    "ModelReply",
    "ToolCall",
    "ToolSpec",
]
