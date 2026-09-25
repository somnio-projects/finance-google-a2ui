"""Provisioned accounts (spec 0027) — who may use the preview.

Firebase (or the dev ``jwt`` provider) says *who* a caller is; this table says
whether that person was **invited**. It is keyed by the lower-cased e-mail,
the one claim both providers carry, and it never stores a credential.
"""

from datetime import datetime
from typing import Final

from sqlalchemy import CheckConstraint, DateTime, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin, UpdatedAtMixin

ROLES: Final[tuple[str, ...]] = ("member", "admin")
STATUSES: Final[tuple[str, ...]] = ("requested", "invited", "active", "revoked")
_ROLE_LIST = ", ".join(f"'{role}'" for role in ROLES)
_STATUS_LIST = ", ".join(f"'{status}'" for status in STATUSES)


class User(TimestampMixin, UpdatedAtMixin, Base):
    """One provisioned account, keyed by its lower-cased e-mail."""

    __tablename__ = "users"
    __table_args__ = (
        CheckConstraint(f"role IN ({_ROLE_LIST})", name="role_allowed"),
        CheckConstraint(f"status IN ({_STATUS_LIST})", name="status_allowed"),
    )

    email: Mapped[str] = mapped_column(String(320), nullable=False, unique=True)
    display_name: Mapped[str | None] = mapped_column(String(120), nullable=True)
    role: Mapped[str] = mapped_column(String(16), nullable=False)
    status: Mapped[str] = mapped_column(String(16), nullable=False)
    invited_by: Mapped[str | None] = mapped_column(String(320), nullable=True)
    last_seen_at: Mapped[datetime | None] = mapped_column(
        DateTime(timezone=True), nullable=True
    )


__all__ = ["ROLES", "STATUSES", "User"]
