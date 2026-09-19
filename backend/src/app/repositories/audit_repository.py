"""Repository for ``AuditEvent`` rows."""

from collections.abc import Sequence
from datetime import datetime

from sqlalchemy import delete, select
from sqlalchemy.exc import SQLAlchemyError

from app.core.errors import DependencyUnavailableError
from app.models.audit_event import AuditEvent
from app.repositories.base import BaseRepository


class AuditRepository(BaseRepository[AuditEvent]):
    """Insert-only access to the audit trail, plus the retention purge."""

    model = AuditEvent

    async def list_for_subject(
        self, subject: str, *, limit: int
    ) -> Sequence[AuditEvent]:
        """Return the newest events recorded for ``subject``."""
        statement = (
            select(AuditEvent)
            .where(AuditEvent.subject == subject)
            .order_by(AuditEvent.created_at.desc())
            .limit(limit)
        )
        try:
            result = await self._session.execute(statement)
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database read failed") from exc
        return result.scalars().all()

    async def purge_older_than(self, cutoff: datetime) -> int:
        """Delete events created before ``cutoff``; return how many went."""
        statement = delete(AuditEvent).where(AuditEvent.created_at < cutoff)
        try:
            result = await self._session.execute(statement)
        except (SQLAlchemyError, OSError) as exc:
            raise DependencyUnavailableError("database write failed") from exc
        return int(result.rowcount)  # pyright: ignore[reportAttributeAccessIssue]


__all__ = ["AuditRepository"]
