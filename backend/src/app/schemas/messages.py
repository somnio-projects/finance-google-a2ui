"""Conversation-message DTOs (spec 0004).

``MessageRole`` mirrors ``app.models.conversation_message.MESSAGE_ROLES``: the
schema layer may not import models, so the allowed values are declared twice
on purpose — in the DTO, which rejects a bad role with 422, and in the
database CHECK constraint, which is the last line of defence. A unit test
asserts the two lists stay identical.
"""

import uuid
from datetime import datetime
from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.pagination import Page

#: Who produced a turn of the conversation.
MessageRole = Literal["user", "assistant", "system"]

#: Longest message body accepted; the request body limit applies on top.
MAX_CONTENT_LENGTH: Final[int] = 8_000


class MessageCreate(BaseModel):
    """Body of `POST /v1/sessions/{session_id}/messages`."""

    model_config = ConfigDict(
        frozen=True,
        json_schema_extra={
            "examples": [
                {
                    "role": "user",
                    "content": ("How did my technology holdings perform last quarter?"),
                }
            ]
        },
    )

    role: MessageRole = Field(
        description=(
            "Who the turn comes from: `user` for the person, `assistant` for "
            "the agent, `system` for instructions that frame the conversation."
        ),
        examples=["user"],
    )
    content: str = Field(
        min_length=1,
        max_length=MAX_CONTENT_LENGTH,
        description="The turn itself, as plain text (1-8 000 characters).",
        examples=["How did my technology holdings perform last quarter?"],
    )


class MessageResponse(BaseModel):
    """One stored turn of a conversation."""

    model_config = ConfigDict(
        frozen=True,
        from_attributes=True,
        json_schema_extra={
            "examples": [
                {
                    "id": "3f1b8a2c-5d6e-4f70-8a91-2b3c4d5e6f70",
                    "session_id": "9e10c0de-2f4b-4c7a-9a1a-1f0d2f5b7c31",
                    "role": "assistant",
                    "content": "Your technology sleeve returned 4.2 % over "
                    "the quarter.",
                    "created_at": "2026-09-19T12:47:02.118904Z",
                }
            ]
        },
    )

    id: uuid.UUID = Field(
        description="Server-assigned identifier of the message.",
        examples=["3f1b8a2c-5d6e-4f70-8a91-2b3c4d5e6f70"],
    )
    session_id: uuid.UUID = Field(
        description="Session the message belongs to.",
        examples=["9e10c0de-2f4b-4c7a-9a1a-1f0d2f5b7c31"],
    )
    role: MessageRole = Field(
        description="Who produced this turn.", examples=["assistant"]
    )
    content: str = Field(
        max_length=MAX_CONTENT_LENGTH,
        description="The turn itself, as stored.",
        examples=["Your technology sleeve returned 4.2 % over the quarter."],
    )
    created_at: datetime = Field(
        description="When the turn was appended (UTC).",
        examples=["2026-09-19T12:47:02.118904Z"],
    )


class MessagePage(Page[MessageResponse]):
    """A page of a conversation, oldest first — the newest turn comes last."""

    model_config = ConfigDict(
        frozen=True,
        json_schema_extra={
            "examples": [
                {
                    "items": [
                        {
                            "id": "3f1b8a2c-5d6e-4f70-8a91-2b3c4d5e6f70",
                            "session_id": "9e10c0de-2f4b-4c7a-9a1a-1f0d2f5b7c31",
                            "role": "user",
                            "content": "How did my technology holdings perform "
                            "last quarter?",
                            "created_at": "2026-09-19T12:45:11.008210Z",
                        }
                    ],
                    "next_cursor": None,
                }
            ]
        },
    )


__all__ = [
    "MAX_CONTENT_LENGTH",
    "MessageCreate",
    "MessagePage",
    "MessageResponse",
    "MessageRole",
]
