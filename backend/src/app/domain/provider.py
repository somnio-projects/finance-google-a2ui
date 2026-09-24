"""How an owner's portfolio is reached (spec 0003 §6, revised by 0020/0035).

The Protocol is **async**. It was synchronous while the only implementation
held a dict, and a database read is not synchronous. Every caller was already
`async` — `Tool.run`, `ViewService` — so this costs four `await`s and buys the
portfolio a life beyond one process.

`InMemoryPortfolioProvider` is no longer the production path; it is the test
double, so unit tests do not need PostgreSQL. The persistent implementation is
`services.portfolio_service.PersistentPortfolioProvider`, which lives there
because the domain may not import a repository.

**Why this changed.** Dev ran `min_instances = 1, max_instances = 2` so the
demo does not pay a cold start. Two processes meant two caches, each seeded
from its own clock: one subject, two portfolios, two `as_of`. The figures
agreed; the moment they were taken did not, and the `ETag` derives from it
(ADR-K D-20). Spec 0020 has the full account. The ceiling is 1 again since
GGU-83 — for the rate limiter, not for this — and the portfolio no longer
depends on it either way.
"""

from typing import Protocol

from app.core.logging import get_logger
from app.core.protocols import Clock
from app.domain.portfolio import Portfolio
from app.domain.seed import seed_portfolio

_logger = get_logger(__name__)


class PortfolioProvider(Protocol):
    """Read and replace the portfolio belonging to one owner.

    ``owner`` is the ownership key, not the token's ``sub``: see
    ``Principal.owner_key`` and spec 0035 OD-1.
    """

    async def get(self, owner: str) -> Portfolio:
        """Return the owner's portfolio, seeding one on first access."""
        ...

    async def save(self, owner: str, portfolio: Portfolio) -> None:
        """Replace the owner's portfolio with ``portfolio``."""
        ...


class InMemoryPortfolioProvider:
    """Hold one portfolio per owner in process memory — **tests only**.

    Owners never share a ``Portfolio`` object, so a mutation saved for one is
    invisible to every other.

    Do not wire this into `bootstrap`. It is exactly the implementation spec
    0020 replaced: it cannot survive a restart and two of it disagree about
    `as_of`.
    """

    def __init__(self, *, clock: Clock) -> None:
        """Create an empty provider that seeds from ``clock``."""
        self._clock = clock
        self._portfolios: dict[str, Portfolio] = {}

    async def get(self, owner: str) -> Portfolio:
        """Return ``owner``'s portfolio, seeding it on first access.

        Args:
            owner: The authenticated caller's ownership key.

        Returns:
            The portfolio, with ``as_of`` fixed at the moment it was seeded.
        """
        portfolio = self._portfolios.get(owner)
        if portfolio is None:
            portfolio = seed_portfolio(as_of=self._clock.now())
            self._portfolios[owner] = portfolio
            # The owner is deliberately absent from the event: it is an
            # e-mail (spec 0035 §5), and as_of plus the symbol set are what a
            # reported wrong number is reproduced from.
            _logger.info(
                "portfolio.seeded",
                as_of=portfolio.as_of.isoformat(),
                symbols=sorted({lot.symbol for lot in portfolio.lots}),
            )
        return portfolio

    async def save(self, owner: str, portfolio: Portfolio) -> None:
        """Replace ``owner``'s portfolio.

        Args:
            owner: The authenticated caller's ownership key.
            portfolio: The portfolio to store.
        """
        self._portfolios[owner] = portfolio


__all__ = ["InMemoryPortfolioProvider", "PortfolioProvider"]
