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
from app.repositories.portfolio_repository import PortfolioRepository

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
    container: Container, *, owners: Sequence[str], reset: bool
) -> tuple[int, int]:
    """Open one session, seed through it, and report counts — never addresses.

    Raises:
        DependencyUnavailableError: When the database cannot be reached.
    """
    async with session_scope(container.session_factory) as session:
        seeded, skipped = await seed_into(
            PortfolioRepository(session),
            owners=owners,
            reset=reset,
            as_of=container.clock.now(),
        )
    log.info(
        "portfolios_seeded",
        seeded=seeded,
        skipped=skipped,
        total=len(owners),
        reset=reset,
    )
    return seeded, skipped


async def main(argv: Sequence[str] | None = None) -> tuple[int, int]:
    """Entry point for the job: settings from the environment, owners from argv."""
    args = parse_args(argv)
    owners = owners_from(args.emails)
    settings = get_settings()
    configure_logging(settings.log_level)
    container = build_container(settings)
    try:
        return await seed(container, owners=owners, reset=args.reset)
    finally:
        await container.engine.dispose()


__all__ = ["main", "seed", "seed_into"]


if __name__ == "__main__":  # pragma: no cover - CLI guard
    asyncio.run(main())
