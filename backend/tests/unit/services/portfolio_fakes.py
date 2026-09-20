"""The repository double the persistent provider is tested against.

Kept beside the tests rather than inside them: two test modules use it, and a
fake that lives in one of them becomes an import from a test file, which is
how test suites grow dependencies nobody intended.

It deliberately models the database's *decisions*, not its storage — finding
nothing, and losing the race — because those are the only two things the
provider has to reason about.
"""

from sqlalchemy.exc import IntegrityError

from app.domain.portfolio import Portfolio
from app.helpers.clock import FixedClock
from app.services.portfolio_service import PersistentPortfolioProvider


class FakeRepository:
    """A `PortfolioRepository` that remembers instead of persisting."""

    def __init__(
        self, *, stored: Portfolio | None = None, conflict: Portfolio | None = None
    ) -> None:
        """Start holding ``stored``, and fail the next write when ``conflict``."""
        self.stored = stored
        self.conflict = conflict
        self.writes = 0

    async def find(self, *, subject: str) -> Portfolio | None:
        """Return what this subject has, if anything."""
        del subject
        return self.stored

    async def replace(self, *, subject: str, portfolio: Portfolio) -> None:
        """Record the write, or lose the race when a conflict was armed."""
        del subject
        self.writes += 1
        if self.conflict is not None:
            self.stored = self.conflict
            raise IntegrityError("insert", (), Exception("duplicate subject"))
        self.stored = portfolio


def provider(repository: object, clock: FixedClock) -> PersistentPortfolioProvider:
    """Build the provider over a fake repository."""
    return PersistentPortfolioProvider(
        repository=repository,  # pyright: ignore[reportArgumentType]
        clock=clock,
    )


__all__ = ["FakeRepository", "provider"]
