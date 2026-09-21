"""Conversation-session DTOs (spec 0004).

The owner never appears in a request or a response: it is the verified `sub`
of the bearer token, so a caller can only ever address its own sessions and
echoing the identifier back would add a leak surface for nothing.
"""

import uuid
from datetime import datetime
from typing import Final

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.pagination import Page

#: Longest title a caller may give a session.
MAX_TITLE_LENGTH: Final[int] = 200


class SessionCreate(BaseModel):
    """Body of `POST /v1/sessions` — everything about it is optional."""

    model_config = ConfigDict(
        frozen=True,
        json_schema_extra={"examples": [{"title": "Retirement portfolio review"}]},
    )

    title: str | None = Field(
        default=None,
        min_length=1,
        max_length=MAX_TITLE_LENGTH,
        description=(
            "Human-readable label for the conversation. Omit it to open an "
            "untitled session; the owner is taken from the token, never from here."
        ),
        examples=["Retirement portfolio review"],
    )


class SessionResponse(BaseModel):
    """One conversation session owned by the caller."""

    model_config = ConfigDict(
        frozen=True,
        from_attributes=True,
        json_schema_extra={
            "examples": [
                {
                    "id": "9e10c0de-2f4b-4c7a-9a1a-1f0d2f5b7c31",
                    "title": "Retirement portfolio review",
                    "created_at": "2026-09-19T12:43:39.042545Z",
                    "updated_at": "2026-09-19T12:47:02.118904Z",
                }
            ]
        },
    )

    id: uuid.UUID = Field(
        description="Server-assigned identifier, used in every session sub-path.",
        examples=["9e10c0de-2f4b-4c7a-9a1a-1f0d2f5b7c31"],
    )
    title: str | None = Field(
        default=None,
        max_length=MAX_TITLE_LENGTH,
        description="Label given at creation, or `null` for an untitled session.",
        examples=["Retirement portfolio review"],
    )
    created_at: datetime = Field(
        description="When the session was opened (UTC).",
        examples=["2026-09-19T12:43:39.042545Z"],
    )
    updated_at: datetime = Field(
        description="Last activity on the session — bumped by every append (UTC).",
        examples=["2026-09-19T12:47:02.118904Z"],
    )


class SessionPage(Page[SessionResponse]):
    """A page of the caller's sessions, newest first."""

    model_config = ConfigDict(
        frozen=True,
        json_schema_extra={
            "examples": [
                {
                    "items": [
                        {
                            "id": "9e10c0de-2f4b-4c7a-9a1a-1f0d2f5b7c31",
                            "title": "Retirement portfolio review",
                            "created_at": "2026-09-19T12:43:39.042545Z",
                            "updated_at": "2026-09-19T12:47:02.118904Z",
                        }
                    ],
                    "next_cursor": None,
                }
            ]
        },
    )


__all__ = ["MAX_TITLE_LENGTH", "SessionCreate", "SessionPage", "SessionResponse"]
