"""Messages inside a conversation session (spec 0004).

The row is reachable only through its session, which is itself scoped by
subject — so isolation is enforced once, on the parent. ``role`` is checked by
the database as well as by the DTO: the schema layer may not import models
(`.claude/rules/backend/architecture.md`), so the allowed values are declared
here and mirrored by ``app.schemas.messages.MessageRole``; a unit test asserts
the two never drift apart.
"""

import uuid
from typing import Final

from sqlalchemy import CheckConstraint, ForeignKey, Index, String, Text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.models.base import Base, TimestampMixin

#: Roles a stored message may carry, mirrored by the ``MessageRole`` literal.
MESSAGE_ROLES: Final[tuple[str, ...]] = ("user", "assistant", "system")
_ROLE_LIST: Final[str] = ", ".join(f"'{role}'" for role in MESSAGE_ROLES)


class ConversationMessage(TimestampMixin, Base):
    """One turn of a conversation, appended in chronological order."""

    __tablename__ = "messages"
    __table_args__ = (
        CheckConstraint(f"role IN ({_ROLE_LIST})", name="role_allowed"),
        Index("ix_messages_session_created", "session_id", "created_at"),
    )

    session_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True),
        ForeignKey("sessions.id", ondelete="CASCADE"),
        nullable=False,
    )
    role: Mapped[str] = mapped_column(String(16), nullable=False)
    content: Mapped[str] = mapped_column(Text, nullable=False)


__all__ = ["MESSAGE_ROLES", "ConversationMessage"]
