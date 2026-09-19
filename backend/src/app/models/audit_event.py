"""Security audit trail (SOC 2 CC7.2 / ISO 27001 A.8.15 — logging of events).

Stores *who* did *what* and *when*, never the credential itself: the token is
represented by its non-reversible fingerprint.
"""

from sqlalchemy import Index, String
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class AuditEvent(TimestampMixin, Base):
    """One row per security-relevant action performed by a principal."""

    __tablename__ = "audit_events"
    __table_args__ = (
        Index("ix_audit_events_subject_created", "subject", "created_at"),
    )

    subject: Mapped[str] = mapped_column(String(255), nullable=False)
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    action: Mapped[str] = mapped_column(String(64), nullable=False)
    # What the action was applied to (flag key, resource id); ``action`` stays
    # ``<domain>.<verb>`` so it never overflows and stays queryable.
    target: Mapped[str | None] = mapped_column(String(255), nullable=True)
    token_fingerprint: Mapped[str] = mapped_column(String(64), nullable=False)
    request_id: Mapped[str] = mapped_column(String(64), nullable=False)


__all__ = ["AuditEvent"]
