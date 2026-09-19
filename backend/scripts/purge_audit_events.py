#!/usr/bin/env python3
"""Apply the audit-trail retention policy (docs/compliance/DATA_RETENTION.md).

Deletes ``audit_events`` older than ``AUDIT_RETENTION_DAYS`` and logs the
count. Runs from the same settings as the API (``DATABASE_URL`` required)::

    make purge-audit                     # locally
    python scripts/purge_audit_events.py # in the Cloud Run job (monthly)
"""

import asyncio
import sys

from app.core.config import get_settings
from app.core.logging import configure_logging, get_logger
from app.helpers.clock import SystemClock
from app.infra.db.engine import create_engine
from app.infra.db.session import create_session_factory, session_scope
from app.repositories.audit_repository import AuditRepository
from app.services.audit_service import AuditService


async def _run() -> int:
    settings = get_settings()
    configure_logging(settings.log_level)
    log = get_logger("purge_audit_events")
    engine = create_engine(settings)
    try:
        async with session_scope(create_session_factory(engine)) as session:
            purged = await AuditService(AuditRepository(session)).purge_expired(
                now=SystemClock().now(), retention_days=settings.audit_retention_days
            )
    finally:
        await engine.dispose()
    log.info(
        "audit_events_purged",
        count=purged,
        retention_days=settings.audit_retention_days,
    )
    return purged


if __name__ == "__main__":  # pragma: no cover - CLI guard
    asyncio.run(_run())
    sys.exit(0)
