"""Record and read the security audit trail."""

from datetime import datetime, timedelta
from typing import Final

from app.core.dto import from_row
from app.core.principal import Principal
from app.models.audit_event import AuditEvent
from app.repositories.audit_repository import AuditRepository
from app.schemas.identity import AuditEventResponse

MAX_HISTORY: Final = 100


class AuditService:
    """Append audit events for a principal and expose their history."""

    def __init__(self, *, repository: AuditRepository) -> None:
        """Bind the service to the request-scoped repository."""
        self._repository = repository

    async def record(
        self,
        principal: Principal,
        *,
        action: str,
        request_id: str,
        target: str | None = None,
    ) -> AuditEvent:
        """Persist that ``principal`` performed ``action`` (on ``target``).

        ``action`` is ``<domain>.<verb>``; ``target`` carries the object acted on.
        """
        event = AuditEvent(
            subject=principal.subject,
            provider=principal.provider,
            action=action,
            target=target,
            token_fingerprint=principal.token_fingerprint,
            request_id=request_id,
        )
        return await self._repository.add(event)

    async def history(
        self, principal: Principal, *, limit: int = 20
    ) -> list[AuditEventResponse]:
        """Return the principal's newest events, capped at ``MAX_HISTORY``."""
        bounded = min(max(limit, 1), MAX_HISTORY)
        events = await self._repository.list_for_subject(
            principal.subject, limit=bounded
        )
        return [from_row(AuditEventResponse, event) for event in events]

    async def purge_expired(self, *, now: datetime, retention_days: int) -> int:
        """Apply the retention policy: delete events older than ``retention_days``."""
        cutoff = now - timedelta(days=retention_days)
        return await self._repository.purge_older_than(cutoff)


__all__ = ["MAX_HISTORY", "AuditService"]
