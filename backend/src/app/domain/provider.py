"""The only access path to a subject's portfolio (ADR-F D-3, spec 0003 AC-8).

Nothing outside this module reaches a stored ``Portfolio``: callers go through
``PortfolioProvider.get`` and ``.save``. That single choke point is what keeps
the in-memory decision reversible — GGU-46 puts a session-backed
implementation behind the same Protocol instead of rewriting every tool.

``get`` **seeds on first access** rather than raising: a demo session must
never open on an error, and seeding there is what fixes ``as_of`` for that
subject from then on. The instant comes from the injected ``Clock``, so this
package still never reads a wall clock of its own.
"""

from typing import Protocol

from app.core.logging import get_logger
from app.core.protocols import Clock
from app.domain.portfolio import Portfolio
from app.domain.seed import seed_portfolio

_logger = get_logger(__name__)


class PortfolioProvider(Protocol):
    """Read and replace the portfolio belonging to one subject."""

    def get(self, subject: str) -> Portfolio:
        """Return the subject's portfolio, seeding one on first access."""
        ...

    def save(self, subject: str, portfolio: Portfolio) -> None:
        """Replace the subject's portfolio with ``portfolio``."""
        ...


class InMemoryPortfolioProvider:
    """Hold one portfolio per subject in process memory (ADR-F D-1).

    Subjects never share a ``Portfolio`` object, so a mutation saved for one is
    invisible to every other — the correctness half of session isolation, with
    uid binding owned by GGU-46.
    """

    def __init__(self, *, clock: Clock) -> None:
        """Create an empty provider that seeds from ``clock``."""
        self._clock = clock
        self._portfolios: dict[str, Portfolio] = {}

    def get(self, subject: str) -> Portfolio:
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

    def save(self, subject: str, portfolio: Portfolio) -> None:
        """Store ``portfolio`` as ``subject``'s current portfolio.

        Args:
            subject: The authenticated principal's subject.
            portfolio: The portfolio to remember from now on.
        """
        self._portfolios[subject] = portfolio


__all__ = ["InMemoryPortfolioProvider", "PortfolioProvider"]
