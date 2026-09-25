"""Give named owners the curated demo portfolio (spec 0035 §4.1).

``PersistentPortfolioProvider`` already seeds on a miss, so nobody *needs*
this to see the demo — the first read makes one. What it exists for is the
two things a first read cannot do: **warm** an account before anybody signs
in, and **reset** one somebody has already moved.

Run it as ``python -m app.jobs.seed_portfolios <email> [<email> ...]``. The
addresses are the positional arguments, and a comma inside one separates
further addresses — because ``gcloud run jobs execute --args=a@x,b@y`` hands
the container exactly that, and a pasted list is the natural thing to type.

**Re-running is safe by construction**: an owner who already has a portfolio
is *skipped*, so a list that overlaps a previous run costs nothing and
nothing is ever doubled. ``--reset`` is the opposite instruction, said out
loud: replace what is there with a freshly seeded copy at today's ``as_of``.

``--all`` names the population instead of the people (spec 0045): every
**admitted** account, read in the same session as the writes. It exists because
the seed's *content* changes under accounts that already hold one — `0044`
replaced an equities portfolio with a crypto one, and every owner seeded before
that day kept their equities, because a stored portfolio is what this job
skips. ``--all --reset`` is the whole instruction for "make the environment
match today's seed", and is **destructive by design**.

**The addresses are not logged** (spec 0035 §5, and `security.md`: e-mails
are PII). The job reports counts, exactly as ``provision_admins`` does; the
operator passed the list and already has it.
"""

import asyncio
from collections.abc import Sequence
from datetime import datetime

import structlog

from app.api.container import Container
from app.bootstrap import build_container
from app.core.config import get_settings
from app.core.logging import configure_logging, get_logger
from app.domain.seed import seed_portfolio
from app.infra.db.session import session_scope
from app.jobs.seed_arguments import owners_from, parse_args
from app.jobs.seed_population import selected_owners
from app.repositories.portfolio_repository import PortfolioRepository
from app.repositories.user_repository import UserRepository

log: structlog.stdlib.BoundLogger = get_logger(__name__)


async def seed_into(
    repository: PortfolioRepository,
    *,
    owners: Sequence[str],
    reset: bool,
    as_of: datetime,
) -> tuple[int, int]:
    """Seed ``owners`` through ``repository``, skipping the ones that have one.

    Args:
        repository: Bound to an open session; this function owns no session.
        owners: Already-normalised ownership keys.
        reset: Replace an existing portfolio instead of leaving it alone.
        as_of: The instant every seeded portfolio is fixed at.

    Returns:
        How many were seeded and how many were skipped.

    Raises:
        DependencyUnavailableError: When the database cannot be reached.
    """
    seeded = skipped = 0
    for owner in owners:
        if not reset and await repository.find(owner=owner) is not None:
            skipped += 1
            continue
        await repository.replace(owner=owner, portfolio=seed_portfolio(as_of=as_of))
        seeded += 1
    return seeded, skipped


async def seed(
    container: Container,
    *,
    owners: Sequence[str],
    reset: bool,
    all_owners: bool = False,
) -> tuple[int, int]:
    """Open one session, seed through it, and report counts — never addresses.

    Args:
        container: The composition root; supplies the session factory and clock.
        owners: Already-normalised ownership keys. Ignored when ``all_owners``.
        reset: Replace an existing portfolio instead of leaving it alone.
        all_owners: Read the owners from the database — every admitted account
            in this environment — instead of taking them from ``owners``. The
            two are resolved in the **same session** as the writes, so the run
            cannot seed against a list that went stale between two connections.

    Returns:
        How many were seeded and how many were skipped.

    Raises:
        DependencyUnavailableError: When the database cannot be reached.
    """
    async with session_scope(container.session_factory) as session:
        selected = await selected_owners(
            UserRepository(session), owners=owners, all_owners=all_owners
        )
        seeded, skipped = await seed_into(
            PortfolioRepository(session),
            owners=selected,
            reset=reset,
            as_of=container.clock.now(),
        )
    log.info(
        "portfolios_seeded",
        seeded=seeded,
        skipped=skipped,
        total=len(selected),
        reset=reset,
        all_owners=all_owners,
    )
    return seeded, skipped


async def main(argv: Sequence[str] | None = None) -> tuple[int, int]:
    """Entry point for the job: settings from the environment, owners from argv."""
    args = parse_args(argv)
    owners = [] if args.all_owners else owners_from(args.emails)
    settings = get_settings()
    configure_logging(settings.log_level)
    container = build_container(settings)
    try:
        return await seed(
            container,
            owners=owners,
            reset=args.reset,
            all_owners=args.all_owners,
        )
    finally:
        await container.engine.dispose()


__all__ = ["main", "seed", "seed_into"]


if __name__ == "__main__":  # pragma: no cover - CLI guard
    asyncio.run(main())
