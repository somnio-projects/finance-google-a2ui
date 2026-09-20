"""How a subject's portfolio is reached (spec 0003 §6, revised by spec 0020).

The Protocol is **async**. It was synchronous while the only implementation
held a dict, and a database read is not synchronous. Every caller was already
`async` — `Tool.run`, `ViewService` — so this costs four `await`s and buys the
portfolio a life beyond one process.

`InMemoryPortfolioProvider` is no longer the production path; it is the test
double, so unit tests do not need PostgreSQL. The persistent implementation is
`services.portfolio_service.PersistentPortfolioProvider`, which lives there
because the domain may not import a repository.

**Why this changed.** Dev runs `min_instances = 1, max_instances = 2` so the
demo does not pay a cold start. Two processes meant two caches, each seeded
from its own clock: one subject, two portfolios, two `as_of`. The figures
agreed; the moment they were taken did not, and the `ETag` derives from it
(ADR-K D-20). Spec 0020 has the full account.
"""

from typing import Protocol

from app.core.logging import get_logger
from app.core.protocols import Clock
from app.domain.portfolio import Portfolio
from app.domain.seed import seed_portfolio

_logger = get_logger(__name__)


class PortfolioProvider(Protocol):
    """Read and replace the portfolio belonging to one subject."""

    async def get(self, subject: str) -> Portfolio:
        """Return the subject's portfolio, seeding one on first access."""
        ...

    async def save(self, subject: str, portfolio: Portfolio) -> None:
        """Replace the subject's portfolio with ``portfolio``."""
        ...


class InMemoryPortfolioProvider:
    """Hold one portfolio per subject in process memory — **tests only**.

    Subjects never share a ``Portfolio`` object, so a mutation saved for one is
    invisible to every other.

    Do not wire this into `bootstrap`. It is exactly the implementation spec
    0020 replaced: it cannot survive a restart and two of it disagree about
    `as_of`.
    """

    def __init__(self, *, clock: Clock) -> None:
        """Create an empty provider that seeds from ``clock``."""
        self._clock = clock
        self._portfolios: dict[str, Portfolio] = {}

    async def get(self, subject: str) -> Portfolio:
        """Return ``subject``'s portfolio, seeding it on first access.

        Args:
            subject: The authenticated principal's subject.

        Returns:
            The portfolio, with ``as_of`` fixed at the moment it was seeded.
        """
        portfolio = self._portfolios.get(subject)
        if portfolio is None:
            portfolio = seed_portfolio(as_of=self._clock.now())
            self._portfolios[subject] = portfolio
            # The subject is deliberately absent from the event: as_of and the
            # symbol set are what a reported wrong number is reproduced from.
            _logger.info(
                "portfolio.seeded",
                as_of=portfolio.as_of.isoformat(),
                symbols=sorted({lot.symbol for lot in portfolio.lots}),
            )
        return portfolio

    async def save(self, subject: str, portfolio: Portfolio) -> None:
        """Replace ``subject``'s portfolio.

        Args:
            subject: The authenticated principal's subject.
            portfolio: The portfolio to store.
        """
        self._portfolios[subject] = portfolio


__all__ = ["InMemoryPortfolioProvider", "PortfolioProvider"]
