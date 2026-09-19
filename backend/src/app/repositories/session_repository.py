"""Repository for conversation sessions and their messages (spec 0004).

**Every** query here is scoped by ``subject``. That is the single place where
cross-subject isolation is enforced (ADR-A D-2, spec 0004 §5): a session
belonging to somebody else must come back as ``None`` — not as a row the
service is then trusted to reject. The primary-key helpers inherited from
``BaseRepository`` are deliberately unused by ``SessionService``; they cannot
see an owner.
"""

import uuid
from collections.abc import Sequence
from datetime import datetime
from typing import Any

from sqlalchemy import Executable, Result, delete, func, select, tuple_, update
from sqlalchemy.exc import SQLAlchemyError

from app.core.errors import DependencyUnavailableError
from app.models.conversation_message import ConversationMessage
from app.models.conversation_session import ConversationSession
from app.repositories.base import BaseRepository

#: The ``(created_at, id)`` position a page resumes after.
type CursorKey = tuple[datetime, uuid.UUID]


class SessionRepository(BaseRepository[ConversationSession]):
    """Subject-scoped access to ``sessions`` and their ``messages``."""

    model = ConversationSession

    async def create(
        self, *, subject: str, provider: str, title: str | None
    ) -> ConversationSession:
        """Insert a session owned by ``subject`` and return it."""
        entity = ConversationSession(subject=subject, provider=provider, title=title)
        await self._persist(entity)
        return entity

    async def get_for_subject(
        self, session_id: uuid.UUID, subject: str
    ) -> ConversationSession | None:
        """Return ``session_id`` **only** when ``subject`` owns it, else ``None``."""
        statement = select(ConversationSession).where(
            ConversationSession.id == session_id,
            ConversationSession.subject == subject,
        )
        result = await self._read(statement)
        return result.scalars().one_or_none()

    async def list_for_subject(
        self, subject: str, *, limit: int, after: CursorKey | None
    ) -> Sequence[ConversationSession]:
        """Return up to ``limit`` of ``subject``'s sessions, newest first."""
        statement = select(ConversationSession).where(
            ConversationSession.subject == subject
        )
        if after is not None:
            statement = statement.where(
                tuple_(ConversationSession.created_at, ConversationSession.id) < after
            )
        statement = statement.order_by(
            ConversationSession.created_at.desc(), ConversationSession.id.desc()
        ).limit(limit)
        return (await self._read(statement)).scalars().all()

    async def delete_for_subject(self, session_id: uuid.UUID, subject: str) -> bool:
        """Delete ``subject``'s session (messages cascade); True when one went."""
        statement = (
            delete(ConversationSession)
            .where(
                ConversationSession.id == session_id,
                ConversationSession.subject == subject,
            )
            .execution_options(synchronize_session=False)
        )
        result = await self._write(statement)
        return bool(result.rowcount)  # pyright: ignore[reportAttributeAccessIssue]

    async def add_message(
        self, session_id: uuid.UUID, *, role: str, content: str
    ) -> ConversationMessage:
        """Append a turn to ``session_id`` and bump the session's ``updated_at``."""
        message = ConversationMessage(session_id=session_id, role=role, content=content)
        await self._persist(message)
        await self._write(
            update(ConversationSession)
            .where(ConversationSession.id == session_id)
            .values(updated_at=func.now())
            .execution_options(synchronize_session=False)
        )
        return message

    async def list_messages(
        self, session_id: uuid.UUID, *, limit: int, after: CursorKey | None
    ) -> Sequence[ConversationMessage]:
        """Return up to ``limit`` turns of ``session_id``, oldest first."""
        statement = select(ConversationMessage).where(
            ConversationMessage.session_id == session_id
        )
        if after is not None:
            statement = statement.where(
                tuple_(ConversationMessage.created_at, ConversationMessage.id) > after
            )
        statement = statement.order_by(
            ConversationMessage.created_at.asc(), ConversationMessage.id.asc()
        ).limit(limit)
        return (await self._read(statement)).scalars().all()

    async def _persist(self, entity: ConversationSession | ConversationMessage) -> None:
        """Insert ``entity`` and reload it so server defaults are populated."""
        try:
            self._session.add(entity)
            await self._session.flush()
            await self._session.refresh(entity)
        except (SQLAlchemyError, OSError) as exc:
            # OSError: asyncpg raises it for a refused connection, unwrapped.
            raise DependencyUnavailableError("database write failed") from exc

    async def _read(self, statement: Executable) -> Result[Any]:
        """Run a query, translating infrastructure failures at the boundary."""
        try:
            return await self._session.execute(statement)
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database read failed") from exc

    async def _write(self, statement: Executable) -> Result[Any]:
        """Run a mutation, translating infrastructure failures at the boundary."""
        try:
            return await self._session.execute(statement)
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database write failed") from exc


__all__ = ["CursorKey", "SessionRepository"]
