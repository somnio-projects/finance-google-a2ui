"""Feature-flag DTOs (spec 0002)."""

from datetime import datetime
from typing import Final

from pydantic import BaseModel, ConfigDict, Field

# ``identity.audit``, ``orders.submit-v2`` — lowercase dotted segments only.
FLAG_KEY_PATTERN: Final[str] = r"^[a-z0-9]+(\.[a-z0-9_-]+)*$"


class FeatureFlagUpdate(BaseModel):
    """Body of ``PUT /v1/admin/feature-flags/{key}``."""

    model_config = ConfigDict(frozen=True)

    enabled: bool = Field(
        description="Target state of the flag after the call.", examples=[False]
    )
    description: str | None = Field(
        default=None,
        max_length=255,
        description="Why the flag was flipped; stored with the row.",
        examples=["hidden until the demo rehearsal"],
    )


class FeatureFlagResponse(BaseModel):
    """Current state of one flag."""

    model_config = ConfigDict(frozen=True, from_attributes=True)

    key: str = Field(
        min_length=3,
        max_length=100,
        pattern=FLAG_KEY_PATTERN,
        description="Flag key, `<domain>.<capability>`.",
        examples=["identity.audit"],
    )
    enabled: bool = Field(
        description="Effective state, with the environment kill-switch applied.",
        examples=[True],
    )
    description: str | None = Field(
        default=None,
        description="Why it is in this state.",
        examples=["demo rehearsal"],
    )
    updated_by: str = Field(
        description="Subject of the admin who last changed it.",
        examples=["firebase:uid-8f2c"],
    )
    updated_at: datetime = Field(
        description="When it was last changed (UTC).",
        examples=["2026-09-19T12:43:39.042545Z"],
    )


__all__ = ["FLAG_KEY_PATTERN", "FeatureFlagResponse", "FeatureFlagUpdate"]
