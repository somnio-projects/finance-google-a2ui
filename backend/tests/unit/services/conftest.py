"""In-memory doubles for the session use cases (spec 0004).

``FakeSessionRepository`` enforces the same subject scoping as the real
repository — the point of the unit suite is that ``SessionService`` never
relies on a row it was not allowed to see, so the double must be able to hide
one.
"""

import uuid
from collections.abc import Sequence
from datetime import UTC, datetime, timedelta

import pytest

from app.core.principal import Principal
from app.models.conversation_message import ConversationMessage
from app.models.conversation_session import ConversationSession
from app.repositories.session_repository import CursorKey
from app.services.session_service import SessionService

NOW = datetime(2026, 9, 19, 12, 0, tzinfo=UTC)


class FakeSessionRepository:
    """In-memory stand-in that scopes every query by subject."""

    def __init__(self) -> None:
        self.sessions: list[ConversationSession] = []
        self.messages: list[ConversationMessage] = []
        self.asked: list[tuple[int, CursorKey | None]] = []

    async def create(
        self, *, subject: str, provider: str, title: str | None
    ) -> ConversationSession:
        entity = ConversationSession(
            id=uuid.uuid4(), subject=subject, provider=provider, title=title
        )
        entity.created_at = NOW + timedelta(seconds=len(self.sessions))
        entity.updated_at = entity.created_at
        self.sessions.append(entity)
        return entity

    async def get_for_subject(
        self, session_id: uuid.UUID, subject: str
    ) -> ConversationSession | None:
        return next(
            (s for s in self.sessions if s.id == session_id and s.subject == subject),
            None,
        )

    async def list_for_subject(
        self, subject: str, *, limit: int, after: CursorKey | None
    ) -> Sequence[ConversationSession]:
        self.asked.append((limit, after))
        return [s for s in self.sessions if s.subject == subject][:limit]

    async def delete_for_subject(self, session_id: uuid.UUID, subject: str) -> bool:
        found = await self.get_for_subject(session_id, subject)
        if found is None:
            return False
        self.sessions.remove(found)
        return True

    async def add_message(
        self, session_id: uuid.UUID, *, role: str, content: str
    ) -> ConversationMessage:
        entity = ConversationMessage(
            id=uuid.uuid4(), session_id=session_id, role=role, content=content
        )
        entity.created_at = NOW + timedelta(seconds=len(self.messages))
        self.messages.append(entity)
        return entity

    async def list_messages(
        self, session_id: uuid.UUID, *, limit: int, after: CursorKey | None
    ) -> Sequence[ConversationMessage]:
        self.asked.append((limit, after))
        return [m for m in self.messages if m.session_id == session_id][:limit]


class RecordingAudit:
    """Captures what the service audits, without a database."""

    def __init__(self) -> None:
        self.calls: list[tuple[str, str | None, str]] = []

    async def record(
        self,
        principal: Principal,
        *,
        action: str,
        request_id: str,
        target: str | None = None,
    ) -> None:
        self.calls.append((action, target, request_id))


@pytest.fixture
def repository() -> FakeSessionRepository:
    return FakeSessionRepository()


@pytest.fixture
def audit() -> RecordingAudit:
    return RecordingAudit()


@pytest.fixture
def service(repository: FakeSessionRepository, audit: RecordingAudit) -> SessionService:
    return SessionService(repository=repository, audit=audit)  # type: ignore[arg-type]


@pytest.fixture
def other() -> Principal:
    """A second, equally well-authenticated subject."""
    return Principal(
        subject=f"other-{uuid.uuid4()}",
        provider="fake",
        token_fingerprint="fedcba9876543210",  # gitleaks:allow - test fixture
    )
