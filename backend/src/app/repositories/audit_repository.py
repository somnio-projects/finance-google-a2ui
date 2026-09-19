"""Repository for ``AuditEvent`` rows."""

from collections.abc import Sequence

from sqlalchemy import select
from sqlalchemy.exc import SQLAlchemyError

from app.core.errors import DependencyUnavailableError
from app.models.audit_event import AuditEvent
from app.repositories.base import BaseRepository


class AuditRepository(BaseRepository[AuditEvent]):
    """Append-only access to the audit trail."""

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


__all__ = ["AuditRepository"]
