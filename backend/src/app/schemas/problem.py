"""RFC 9457 problem-details body used for every error response."""

from pydantic import BaseModel, ConfigDict, Field


class ProblemDetails(BaseModel):
    """Machine-readable error envelope.

    ``type`` is a stable URI built from the error code so clients branch on
    it (e.g. refresh on ``auth/expired-token``) instead of parsing text.
    """

    model_config = ConfigDict(frozen=True)

    type: str = Field(examples=["https://errors.finance-a2ui/auth/expired-token"])
    title: str
    status: int = Field(ge=400, le=599)
    detail: str
    instance: str | None = None
    request_id: str | None = None


__all__ = ["ProblemDetails"]
