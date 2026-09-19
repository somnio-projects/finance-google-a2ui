"""Conversation-session use cases (spec 0004, GGU-46).

The owner is always ``principal.subject``, never a value taken from the
request, and a session the caller does not own raises ``NotFoundError`` —
never ``AuthorizationError``, because a 403 would confirm that the id exists
(ADR-A D-2). Ownership is resolved once, in ``_require_own``, which every
message operation goes through before it can name a session.
"""

import uuid
from collections.abc import Sequence

from app.core.dto import from_row
from app.core.errors import NotFoundError
from app.core.principal import Principal
from app.helpers.cursor import decode_cursor, encode_cursor
from app.models.conversation_message import ConversationMessage
from app.models.conversation_session import ConversationSession
from app.repositories.session_repository import CursorKey, SessionRepository
from app.schemas.messages import MessageCreate, MessagePage, MessageResponse
from app.schemas.sessions import SessionPage, SessionResponse
from app.services.audit_service import AuditService


class SessionService:
    """Create, read and delete the caller's own sessions and messages."""

    def __init__(self, *, repository: SessionRepository, audit: AuditService) -> None:
        """Inject the request-scoped repository and audit trail."""
        self._repository = repository
        self._audit = audit

    async def create(
        self, principal: Principal, *, title: str | None, request_id: str
    ) -> SessionResponse:
        """Open a session owned by the caller and audit it (AC-1)."""
        entity = await self._repository.create(
            subject=principal.subject, provider=principal.provider, title=title
        )
        await self._record(principal, "session.create", entity.id, request_id)
        return from_row(SessionResponse, entity)

    async def get(
        self, principal: Principal, session_id: uuid.UUID, *, request_id: str
    ) -> SessionResponse:
        """Return the caller's session, or 404 for anybody else's (AC-3)."""
        entity = await self._require_own(principal, session_id)
        await self._record(principal, "session.read", session_id, request_id)
        return from_row(SessionResponse, entity)

    async def list_sessions(
        self, principal: Principal, *, limit: int, cursor: str | None, request_id: str
    ) -> SessionPage:
        """Return a page of the caller's sessions, newest first (AC-2)."""
        rows = await self._repository.list_for_subject(
            principal.subject, limit=limit + 1, after=_after(cursor)
        )
        await self._record(principal, "session.list", None, request_id)
        return SessionPage(
            items=[from_row(SessionResponse, row) for row in rows[:limit]],
            next_cursor=_next_cursor(rows, limit),
        )

    async def delete(
        self, principal: Principal, session_id: uuid.UUID, *, request_id: str
    ) -> None:
        """Delete the caller's session; 404 for an unknown or foreign one (AC-4)."""
        if not await self._repository.delete_for_subject(session_id, principal.subject):
            raise NotFoundError(f"session {session_id} not found")
        await self._record(principal, "session.delete", session_id, request_id)

    async def append_message(
        self,
        principal: Principal,
        session_id: uuid.UUID,
        *,
        message: MessageCreate,
        request_id: str,
    ) -> MessageResponse:
        """Append a turn to the caller's session (AC-5)."""
        await self._require_own(principal, session_id)
        entity = await self._repository.add_message(
            session_id, role=message.role, content=message.content
        )
        await self._record(principal, "session.append", session_id, request_id)
        return from_row(MessageResponse, entity)

    async def list_messages(
        self,
        principal: Principal,
        session_id: uuid.UUID,
        *,
        limit: int,
        cursor: str | None,
        request_id: str,
    ) -> MessagePage:
        """Return a page of the conversation, oldest first (AC-6)."""
        await self._require_own(principal, session_id)
        rows = await self._repository.list_messages(
            session_id, limit=limit + 1, after=_after(cursor)
        )
        await self._record(principal, "session.read", session_id, request_id)
        return MessagePage(
            items=[from_row(MessageResponse, row) for row in rows[:limit]],
            next_cursor=_next_cursor(rows, limit),
        )

    async def _require_own(
        self, principal: Principal, session_id: uuid.UUID
    ) -> ConversationSession:
        """Return the session when the caller owns it, else raise ``NotFoundError``."""
        entity = await self._repository.get_for_subject(session_id, principal.subject)
        if entity is None:
            # Same error for "does not exist" and "belongs to somebody else".
            raise NotFoundError(f"session {session_id} not found")
        return entity

    async def _record(
        self,
        principal: Principal,
        action: str,
        target: uuid.UUID | None,
        request_id: str,
    ) -> None:
        """Write one audit event for a session action."""
        await self._audit.record(
            principal,
            action=action,
            target=None if target is None else str(target),
            request_id=request_id,
        )


def _after(cursor: str | None) -> CursorKey | None:
    """Decode ``cursor`` into a keyset position, or ``None`` for the first page."""
    return None if cursor is None else decode_cursor(cursor)


def _next_cursor(
    rows: Sequence[ConversationSession] | Sequence[ConversationMessage], limit: int
) -> str | None:
    """Return the cursor continuing after ``limit`` rows, or ``None`` at the end."""
    if len(rows) <= limit:
        return None
    last = rows[limit - 1]
    return encode_cursor(last.created_at, last.id)


__all__ = ["SessionService"]
