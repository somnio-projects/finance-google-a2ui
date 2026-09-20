"""Conversation sessions owned by a verified subject (spec 0004).

``subject`` is the ownership key: it holds the ``sub`` claim of the token the
session was opened with (ADR-A D-1), and every query in
``SessionRepository`` filters on it. The index leads with ``subject`` for the
same reason — the scoped query is the only query.
"""

from datetime import datetime

from sqlalchemy import DateTime, Index, String, func
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin


class ConversationSession(TimestampMixin, Base):
    """One conversation between a subject and the agent."""

    __tablename__ = "sessions"
    __table_args__ = (Index("ix_sessions_subject_created", "subject", "created_at"),)

    subject: Mapped[str] = mapped_column(String(255), nullable=False)
    provider: Mapped[str] = mapped_column(String(32), nullable=False)
    title: Mapped[str | None] = mapped_column(String(200), nullable=True)
    updated_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        nullable=False,
        server_default=func.now(),
        onupdate=func.now(),
    )


__all__ = ["ConversationSession"]
