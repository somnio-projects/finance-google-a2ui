"""The provisioning registry's DTOs (spec 0027): accounts as an admin sees them."""

from datetime import datetime
from typing import Annotated, Final, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

#: Loose on purpose: the identity provider validates the mailbox; this only
#: rejects what could never be an address, and lower-cases what could.
EMAIL_PATTERN: Final[str] = r"^[^@\s]+@[^@\s]+\.[^@\s]+$"
Email = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True,
        to_lower=True,
        min_length=6,
        max_length=320,
        pattern=EMAIL_PATTERN,
    ),
]
UserRole = Literal["member", "admin"]
UserStatus = Literal["requested", "invited", "active", "revoked"]


class UserInvite(BaseModel):
    """Body of ``POST /v1/admin/users`` — invite (or re-invite) an account."""

    model_config = ConfigDict(
        frozen=True,
        json_schema_extra={
            "examples": [{"email": "reviewer@google.com", "display_name": "Reviewer"}]
        },
    )

    email: Email = Field(description="Who is invited; stored lower-cased.")
    display_name: str | None = Field(
        default=None, max_length=120, description="How the shell greets them."
    )
    role: UserRole = Field(default="member", description="What they may do.")


class UserStatusUpdate(BaseModel):
    """Body of ``PATCH /v1/admin/users/{email}``."""

    model_config = ConfigDict(
        frozen=True, json_schema_extra={"examples": [{"status": "revoked"}]}
    )

    status: UserStatus = Field(description="The account's new status.")


class UserResponse(BaseModel):
    """One provisioned account, as an admin sees it."""

    model_config = ConfigDict(
        frozen=True,
        from_attributes=True,
        json_schema_extra={
            "examples": [
                {
                    "email": "reviewer@google.com",
                    "display_name": "Reviewer",
                    "role": "member",
                    "status": "invited",
                    "invited_by": "demo@somnio.dev",
                    "last_seen_at": None,
                    "created_at": "2026-09-21T12:00:00Z",
                }
            ]
        },
    )

    email: str = Field(max_length=320, description="Lower-cased e-mail.")
    display_name: str | None = Field(
        default=None, max_length=120, description="How the shell greets them."
    )
    role: UserRole = Field(description="`member` or `admin`.")
    status: UserStatus = Field(description="Where the account stands.")
    invited_by: str | None = Field(
        default=None, max_length=320, description="Who invited it; `bootstrap` at boot."
    )
    last_seen_at: datetime | None = Field(default=None, description="Last sign-in.")
    created_at: datetime = Field(description="When the row was created.")


__all__ = [
    "EMAIL_PATTERN",
    "Email",
    "UserInvite",
    "UserResponse",
    "UserRole",
    "UserStatus",
    "UserStatusUpdate",
]
