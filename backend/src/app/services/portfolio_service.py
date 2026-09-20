"""The production `PortfolioProvider`, backed by PostgreSQL (spec 0020).

It lives here rather than in `domain/` because it needs a repository, and the
domain may not import one (`architecture.md`). The Protocol stays in the
domain; this is the implementation that satisfies it.

It is built **per request**, not per process: a repository holds the request's
`AsyncSession`, whose commit and rollback belong to `session_scope`. A
process-wide provider holding one would outlive it. That is why
`Container.portfolio` no longer exists (spec 0020 §4.2).
"""

from sqlalchemy.exc import IntegrityError

from app.core.errors import DependencyUnavailableError
from app.core.logging import get_logger
from app.core.protocols import Clock
from app.domain.portfolio import Portfolio
from app.domain.seed import seed_portfolio
from app.repositories.portfolio_repository import PortfolioRepository

_logger = get_logger(__name__)


class PersistentPortfolioProvider:
    """Read one subject's portfolio from the database, seeding it once."""

    def __init__(self, *, repository: PortfolioRepository, clock: Clock) -> None:
        """Bind the provider to the request's repository and the clock."""
        self._repository = repository
        self._clock = clock

    async def get(self, subject: str) -> Portfolio:
        """Return ``subject``'s portfolio, seeding and storing it on a miss.

        Seeding on a miss rather than raising is spec 0003 OD-7: a demo
        session must never open on an error.

        The race is decided by the database, not by this code. Two instances
        seeding the same new subject both write; `uq_portfolios_subject` lets
        exactly one win, and the loser re-reads what the winner stored. It
        cannot invent a second portfolio — the property the in-memory
        implementation could not offer.

        Args:
            subject: The authenticated principal's subject.

        Returns:
            The stored portfolio, with the ``as_of`` it was first seeded with.

        Raises:
            DependencyUnavailableError: If the portfolio is neither found nor
                creatable — a lost race whose winner then vanished.
        """
        stored = await self._repository.find(subject=subject)
        if stored is not None:
            return stored
        portfolio = seed_portfolio(as_of=self._clock.now())
        try:
            await self._repository.replace(subject=subject, portfolio=portfolio)
        except IntegrityError:
            return await self._reread(subject)
        # The subject is deliberately absent from the event: as_of and the
        # symbol set are what a reported wrong number is reproduced from.
        _logger.info(
            "portfolio.seeded",
            as_of=portfolio.as_of.isoformat(),
            symbols=sorted({lot.symbol for lot in portfolio.lots}),
        )
        # Re-read rather than return what was just seeded. `NUMERIC(38, 18)`
        # hands back a `Decimal` carrying eighteen places, and the in-memory
        # one does not: returning the seeded object would make the **first**
        # answer of a session differ in its raw `value` strings from every
        # answer after it. ADR-K D-20 requires a given request to be
        # byte-identical for the life of the session, and the integration
        # flow test caught this the moment persistence landed.
        return await self._reread(subject)

    async def save(self, subject: str, portfolio: Portfolio) -> None:
        """Replace ``subject``'s stored portfolio.

        Args:
            subject: The authenticated principal's subject.
            portfolio: The portfolio to store.
        """
        await self._repository.replace(subject=subject, portfolio=portfolio)

    async def _reread(self, subject: str) -> Portfolio:
        """Return what the writer that won the race stored."""
        winner = await self._repository.find(subject=subject)
        if winner is None:
            msg = "portfolio could not be created or read"
            raise DependencyUnavailableError(msg)
        return winner


__all__ = ["PersistentPortfolioProvider"]
