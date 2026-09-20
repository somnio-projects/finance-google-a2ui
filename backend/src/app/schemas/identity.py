"""Identity-related response models."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field


class MeResponse(BaseModel):
    """What the API knows about the caller — never the token itself."""

    model_config = ConfigDict(
        frozen=True,
        json_schema_extra={
            "examples": [
                {
                    "subject": "firebase:uid-8f2c",
                    "provider": "oidc",
                    "email": "reviewer@example.test",
                    "scopes": ["read"],
                }
            ]
        },
    )

    subject: str = Field(
        description="Stable identifier from the identity provider (`sub`).",
        examples=["firebase:uid-8f2c"],
    )
    provider: str = Field(
        description="Verifier that authenticated the token.", examples=["oidc"]
    )
    email: str | None = Field(
        default=None,
        description="E-mail claim when the provider supplies one; never stored.",
        examples=["reviewer@example.test"],
    )
    scopes: list[str] = Field(
        description="Granted scopes, lower-cased and sorted.", examples=[["admin"]]
    )


class AuditEventResponse(BaseModel):
    """One audit trail entry."""

    model_config = ConfigDict(
        frozen=True,
        from_attributes=True,
        json_schema_extra={
            "examples": [
                {
                    "action": "feature_flag.update",
                    "target": "views.batch-render",
                    "provider": "jwt",
                    "request_id": "3ed55388-087e-419f-acbe-34f663fc04c4",
                    "created_at": "2026-09-19T12:43:39.042545Z",
                }
            ]
        },
    )

    action: str = Field(
        description="What was done, as `<domain>.<verb>`.",
        examples=["feature_flag.update"],
    )
    target: str | None = Field(
        default=None,
        description="What the action was applied to (flag key, resource id).",
        examples=["identity.audit"],
    )
    provider: str = Field(
        description="Verifier that authenticated the actor.", examples=["jwt"]
    )
    request_id: str = Field(
        description="Correlates with the `X-Request-ID` response header.",
        examples=["3ed55388-087e-419f-acbe-34f663fc04c4"],
    )
    created_at: datetime = Field(
        description="When the event was recorded (UTC).",
        examples=["2026-09-19T12:43:39.042545Z"],
    )


__all__ = ["AuditEventResponse", "MeResponse"]
