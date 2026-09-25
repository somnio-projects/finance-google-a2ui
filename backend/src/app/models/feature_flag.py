"""Runtime feature flags (spec 0002) — enable/disable endpoints on demand."""

from datetime import datetime

from sqlalchemy import Boolean, DateTime, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, UpdatedAtMixin


class FeatureFlag(UpdatedAtMixin, Base):
    """One row per flag key; absence means "use the gate's default"."""

    __tablename__ = "feature_flags"

    key: Mapped[str] = mapped_column(String(100), primary_key=True)
    enabled: Mapped[bool] = mapped_column(Boolean, nullable=False)
    description: Mapped[str | None] = mapped_column(String(255), nullable=True)
    updated_by: Mapped[str] = mapped_column(String(255), nullable=False)
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True), nullable=False, server_default=func.now()
    )


__all__ = ["FeatureFlag"]
