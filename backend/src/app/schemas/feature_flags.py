"""Feature-flag DTOs (spec 0002)."""

from datetime import datetime
from typing import Final

from pydantic import BaseModel, ConfigDict, Field

# ``identity.audit``, ``orders.submit-v2`` — lowercase dotted segments only.
FLAG_KEY_PATTERN: Final = r"^[a-z0-9]+(\.[a-z0-9_-]+)*$"


class FeatureFlagUpdate(BaseModel):
    """Body of ``PUT /v1/admin/feature-flags/{key}``."""

    model_config = ConfigDict(frozen=True)

    enabled: bool
    description: str | None = Field(default=None, max_length=255)


class FeatureFlagResponse(BaseModel):
    """Current state of one flag."""

    model_config = ConfigDict(frozen=True, from_attributes=True)

    key: str = Field(min_length=3, max_length=100, pattern=FLAG_KEY_PATTERN)
    enabled: bool
    description: str | None = None
    updated_by: str
    updated_at: datetime


__all__ = ["FLAG_KEY_PATTERN", "FeatureFlagResponse", "FeatureFlagUpdate"]
