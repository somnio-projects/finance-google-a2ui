"""In-memory doubles for the provisioning use cases (spec 0027)."""

import uuid
from collections.abc import Sequence
from datetime import UTC, datetime

from app.core.principal import Principal
from app.models.audit_event import AuditEvent
from app.models.user import User

NOW = datetime(2026, 9, 21, 12, 0, tzinfo=UTC)


class FakeUserRepository:
    """Stand-in for ``UserRepository`` keyed by e-mail."""

    def __init__(self) -> None:
        self.rows: dict[str, User] = {}

    async def find_by_email(self, email: str) -> User | None:
        return self.rows.get(email)

    async def list_all(self, *, limit: int) -> Sequence[User]:
        return list(self.rows.values())[:limit]

    async def upsert(
        self,
        *,
        email: str,
        display_name: str | None,
        role: str,
        status: str,
        invited_by: str | None,
    ) -> User:
        row = self.rows.get(email) or User(id=uuid.uuid4(), email=email)
        row.created_at = getattr(row, "created_at", None) or NOW
        row.role, row.status, row.invited_by = role, status, invited_by
        if display_name is not None:
            row.display_name = display_name
        self.rows[email] = row
        return row

    async def touch(
        self, row: User, *, seen_at: datetime, status: str | None = None
    ) -> User:
        row.last_seen_at = seen_at
        if status is not None:
            row.status = status
        return row


class FakeAuditRepository:
    """Records every event handed to it."""

    def __init__(self) -> None:
        self.events: list[AuditEvent] = []

    async def add(self, entity: AuditEvent) -> AuditEvent:
        entity.created_at = NOW
        self.events.append(entity)
        return entity


def admin(*, mfa: bool = False, email: str | None = "root@somnio.dev") -> Principal:
    """An admin principal, with or without a second factor."""
    return Principal(
        subject="admin-1",
        provider="fake",
        email=email,
        scopes=frozenset({"admin"}),
        token_fingerprint="fedcba9876543210",  # gitleaks:allow - test fixture
        auth_methods=frozenset({"mfa"}) if mfa else frozenset(),
    )


def member(email: str | None = "person@example.test") -> Principal:
    """A plain signed-in principal."""
    return Principal(
        subject="member-1",
        provider="fake",
        email=email,
        scopes=frozenset({"read"}),
        token_fingerprint="0123456789abcdef",  # gitleaks:allow - test fixture
    )
