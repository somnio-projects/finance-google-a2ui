"""Identity-related response models."""

from datetime import datetime

from pydantic import BaseModel, ConfigDict


class MeResponse(BaseModel):
    """What the API knows about the caller — never the token itself."""

    model_config = ConfigDict(frozen=True)

    subject: str
    provider: str
    email: str | None
    scopes: list[str]


class AuditEventResponse(BaseModel):
    """One audit trail entry."""

    model_config = ConfigDict(frozen=True, from_attributes=True)

    action: str
    target: str | None = None
    provider: str
    request_id: str
    created_at: datetime


__all__ = ["AuditEventResponse", "MeResponse"]
