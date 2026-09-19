"""RFC 9457 problem-details body used for every error response."""

from pydantic import BaseModel, ConfigDict, Field


class ProblemDetails(BaseModel):
    """Machine-readable error envelope.

    ``type`` is a stable URI built from the error code so clients branch on
    it (e.g. refresh on ``auth/expired-token``) instead of parsing text.
    """

    model_config = ConfigDict(frozen=True)

    type: str = Field(
        description="Stable URI identifying the error code; branch on this.",
        examples=["https://errors.finance-a2ui/auth/expired-token"],
    )
    title: str = Field(
        description="Short, human-readable summary (the status phrase).",
        examples=["Unauthorized"],
    )
    status: int = Field(
        ge=400, le=599, description="HTTP status of this response.", examples=[401]
    )
    detail: str = Field(
        description="Safe-to-expose explanation; never contains internals.",
        examples=["The bearer token has expired."],
    )
    instance: str | None = Field(
        default=None, description="Path that produced the error.", examples=["/v1/me"]
    )
    request_id: str | None = Field(
        default=None,
        description="Correlates with the `X-Request-ID` response header.",
        examples=["3ed55388-087e-419f-acbe-34f663fc04c4"],
    )


__all__ = ["ProblemDetails"]
