"""Put named people in the provisioning registry before they sign in.

``AUTH_OPEN_ENROLMENT`` already admits a verified identity the registry has
never seen (spec 0040), so nobody *needs* this to get in. What it exists for
is the thing enrolment cannot do: **have the row before anybody signs in** —
so a demo audience is a list somebody decided on rather than a side effect of
who happened to open the app, and so an environment with enrolment off can
still be opened to named people.

Run it as ``python -m app.jobs.provision_users <email> [<email> ...]``. The
addresses are positional, and a comma inside one separates further addresses,
because ``gcloud run jobs execute --args=a@x,b@y`` hands the container exactly
that. Same shape as ``seed_portfolios``, deliberately: one list, one job, one
way to type it.

**Members, never admins.** The first admins come from
``AUTH_BOOTSTRAP_ADMINS`` and nothing else creates one (spec 0027 OD-2). This
job is the audience, not the operators.

**An existing row is never touched**, whatever its status. That is the same
ruling enrolment makes and for the same reason: a ``revoked`` account is an
offboarding somebody performed, and a job run must not undo it. Re-running is
therefore safe and a list that overlaps a previous run costs nothing.

**The addresses are not logged** (`security.md`: e-mails are PII). The job
reports counts; the operator passed the list and already has it.
"""

import asyncio
from collections.abc import Sequence

import structlog

from app.api.container import Container
from app.bootstrap import build_container
from app.core.config import get_settings
from app.core.logging import configure_logging, get_logger
from app.infra.db.session import session_scope
from app.jobs.provision_arguments import parse_args
from app.jobs.seed_arguments import owners_from
from app.repositories.user_repository import UserRepository

log: structlog.stdlib.BoundLogger = get_logger(__name__)

#: What the registry records as the inviter, so an audit reader can tell a
#: row this job wrote from one an admin invited or one that enrolled itself.
PROVISION_JOB: str = "provision-users-job"


async def provision_into(
    repository: UserRepository, *, emails: Sequence[str]
) -> tuple[int, int]:
    """Add the missing accounts through ``repository``; leave the rest alone.

    Args:
        repository: Bound to an open session; this function owns no session.
        emails: Already-normalised, lower-cased addresses.

    Returns:
        How many were added and how many were left as they were.

    Raises:
        DependencyUnavailableError: When the database cannot be reached.
    """
    added = untouched = 0
    for email in emails:
        if await repository.find_by_email(email) is not None:
            untouched += 1
            continue
        await repository.upsert(
            email=email,
            display_name=None,
            role="member",
            status="active",
            invited_by=PROVISION_JOB,
        )
        added += 1
    return added, untouched


async def provision(container: Container, *, emails: Sequence[str]) -> tuple[int, int]:
    """Open one session, provision through it, and report counts.

    Raises:
        DependencyUnavailableError: When the database cannot be reached.
    """
    async with session_scope(container.session_factory) as session:
        added, untouched = await provision_into(UserRepository(session), emails=emails)
    log.info(
        "users_provisioned",
        added=added,
        untouched=untouched,
        total=len(emails),
    )
    return added, untouched


async def main(argv: Sequence[str] | None = None) -> tuple[int, int]:
    """Entry point: settings from the environment, addresses from argv."""
    args = parse_args(argv)
    emails = owners_from(args.emails)
    settings = get_settings()
    configure_logging(settings.log_level)
    container = build_container(settings)
    try:
        return await provision(container, emails=emails)
    finally:
        await container.engine.dispose()


__all__ = ["PROVISION_JOB", "main", "provision", "provision_into"]


if __name__ == "__main__":  # pragma: no cover - CLI guard
    asyncio.run(main())
