"""Access DTOs (spec 0027): may this caller in, and how does one ask.

``PROVISIONED`` is the one predicate every decision reads; the two sentences
are the words the client shows verbatim (N-9), written once, here.
"""

from typing import Final, Literal

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.users import Email, UserRole, UserStatus

#: The statuses that may sign in. ``requested`` is waiting for an admin;
#: ``revoked`` is offboarded and stays in the table as the record of it.
PROVISIONED: Final[frozenset[str]] = frozenset({"invited", "active"})
NOT_PROVISIONED_MESSAGE: Final[str] = "This account isn't provisioned for the preview."
WELCOME_MESSAGE: Final[str] = "Welcome back."


class AccessResponse(BaseModel):
    """``GET /v1/me/access`` — whether the caller may use the preview."""

    model_config = ConfigDict(
        frozen=True,
        json_schema_extra={
            "examples": [
                {
                    "email": "reviewer@google.com",
                    "provisioned": True,
                    "status": "active",
                    "role": "member",
                    "display_name": "Reviewer",
                    "message": WELCOME_MESSAGE,
                }
            ]
        },
    )

    email: str | None = Field(
        default=None, max_length=320, description="The token's e-mail, lower-cased."
    )
    provisioned: bool = Field(description="Whether the shell may open.")
    status: UserStatus | None = Field(
        default=None, description="The registry's status, when the e-mail is known."
    )
    role: UserRole | None = Field(default=None, description="`member` or `admin`.")
    display_name: str | None = Field(
        default=None, max_length=120, description="How the shell greets them."
    )
    message: str = Field(
        max_length=120, description="The sentence the client shows, verbatim."
    )


class AccessRequest(BaseModel):
    """Body of ``POST /v1/access-requests`` — the *Request access* link."""

    model_config = ConfigDict(
        frozen=True, json_schema_extra={"examples": [{"email": "you@company.com"}]}
    )

    email: Email = Field(description="The mailbox asking for an invitation.")


class PreviewSignIn(BaseModel):
    """Body of ``POST /v1/preview-sign-ins`` — the local e-mail sign-in."""

    model_config = ConfigDict(
        frozen=True, json_schema_extra={"examples": [{"email": "demo@somnio.dev"}]}
    )

    email: Email = Field(description="A provisioned e-mail.")


class PreviewSignInResponse(BaseModel):
    """A minted bearer token for the local stack."""

    model_config = ConfigDict(
        frozen=True,
        json_schema_extra={
            "examples": [
                {"access_token": "eyJ…", "token_type": "Bearer", "expires_in": 28800}
            ]
        },
    )

    access_token: str = Field(description="HS256 token the `jwt` provider accepts.")
    token_type: Literal["Bearer"] = Field(
        default="Bearer", description="Always `Bearer`, as the header expects."
    )
    expires_in: int = Field(ge=1, description="Seconds until it expires.")


__all__ = [
    "NOT_PROVISIONED_MESSAGE",
    "PROVISIONED",
    "WELCOME_MESSAGE",
    "AccessRequest",
    "AccessResponse",
    "PreviewSignIn",
    "PreviewSignInResponse",
]
