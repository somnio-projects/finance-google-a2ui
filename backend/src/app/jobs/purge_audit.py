"""Retention job for ``audit_events`` (docs/compliance/DATA_RETENTION.md).

Deletes rows older than ``Settings.audit_retention_days`` and logs the count
and the cutoff, so the job history is the evidence of the purge (A.8.10).
Run it as ``python -m app.jobs.purge_audit`` (``make purge-audit`` locally, the
Cloud Run job in production) — the image ships ``src/app`` only.
"""

import asyncio

import structlog

from app.api.container import Container
from app.bootstrap import build_container
from app.core.config import get_settings
from app.core.logging import configure_logging, get_logger
from app.infra.db.session import session_scope
from app.repositories.audit_repository import AuditRepository
from app.services.audit_service import AuditService

log: structlog.stdlib.BoundLogger = get_logger(__name__)


async def run(container: Container) -> int:
    """Purge expired audit events using the container's session factory.

    Returns:
        Number of rows deleted.

    Raises:
        DependencyUnavailableError: When the database cannot be reached.
    """
    settings = container.settings
    now = container.clock.now()
    async with session_scope(container.session_factory) as session:
        service = AuditService(repository=AuditRepository(session))
        purged = await service.purge_expired(
            now=now, retention_days=settings.audit_retention_days
        )
    log.info(
        "audit_events_purged",
        count=purged,
        retention_days=settings.audit_retention_days,
        cutoff=(now - settings.audit_retention).isoformat(),
    )
    return purged


async def main() -> int:
    """Entry point for the scheduled job: settings from the environment."""
    settings = get_settings()
    configure_logging(settings.log_level)
    container = build_container(settings)
    try:
        return await run(container)
    finally:
        await container.engine.dispose()


__all__ = ["main", "run"]


if __name__ == "__main__":  # pragma: no cover - CLI guard
    asyncio.run(main())
