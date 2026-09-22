"""Provision the bootstrap admins at startup (spec 0027 OD-2).

A registry with no admin in it can never gain one through the API, so the
first admins come from configuration: ``AUTH_BOOTSTRAP_ADMINS``. Idempotent,
and a database that is not there yet is a warning, not a failed boot — the
readiness probe already says the database is down.
"""

from collections.abc import Sequence

import structlog
from sqlalchemy.ext.asyncio import AsyncSession, async_sessionmaker

from app.core.errors import DependencyUnavailableError
from app.infra.db.session import session_scope
from app.repositories.user_repository import UserRepository

log: structlog.stdlib.BoundLogger = structlog.get_logger(__name__)
BOOTSTRAP = "bootstrap"


async def ensure_admins(repository: UserRepository, emails: Sequence[str]) -> int:
    """Make every e-mail in ``emails`` an active admin; return how many changed."""
    changed = 0
    for raw in emails:
        email = raw.strip().lower()
        row = await repository.find_by_email(email)
        if row is not None and (row.role, row.status) == ("admin", "active"):
            continue
        await repository.upsert(
            email=email,
            display_name=None,
            role="admin",
            status="active",
            invited_by=BOOTSTRAP,
        )
        changed += 1
    return changed


async def provision_admins(
    *,
    emails: Sequence[str],
    session_factory: async_sessionmaker[AsyncSession],
) -> int:
    """Make ``emails`` active admins; return how many rows changed, -1 on failure."""
    if not emails:
        return 0
    try:
        async with session_scope(session_factory) as session:
            changed = await ensure_admins(UserRepository(session), emails)
    except DependencyUnavailableError:
        log.warning("bootstrap_admins_skipped", reason="database unavailable")
        return -1
    log.info("bootstrap_admins_provisioned", changed=changed, total=len(emails))
    return changed


__all__ = ["BOOTSTRAP", "ensure_admins", "provision_admins"]
