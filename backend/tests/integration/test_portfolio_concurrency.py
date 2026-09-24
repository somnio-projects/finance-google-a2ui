"""Two sessions at once, and the isolation between owners (spec 0020).

Split from `test_portfolio_repository.py` under the 150-line budget, along the
seam that was already there: that file asks *is what I wrote what I read*, this
asks *what happens when two of us write at the same time, and can I see yours*.

Both need a real PostgreSQL. A fake repository cannot enforce a UNIQUE
constraint, so it would agree with whatever the code does — and the code was
wrong the first time this ran: an `IntegrityError` aborts the transaction, so
the loser's re-read failed until `replace` was wrapped in a SAVEPOINT.
"""

import asyncio
from datetime import timedelta

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings
from app.helpers.clock import FixedClock
from app.infra.db.engine import create_engine
from app.infra.db.session import create_session_factory
from app.repositories.portfolio_repository import PortfolioRepository
from app.services.portfolio_service import PersistentPortfolioProvider
from tests.conftest import FROZEN_NOW

pytestmark = pytest.mark.integration


def _provider(session: AsyncSession, clock: FixedClock) -> PersistentPortfolioProvider:
    """Build the production provider over a real session."""
    return PersistentPortfolioProvider(
        repository=PortfolioRepository(session), clock=clock
    )


async def test_two_concurrent_first_accesses_produce_one_portfolio(
    integration_settings: Settings,
) -> None:
    """AC-6 — the race the unique constraint decides.

    Two sessions, genuinely concurrent, both seeding the same new owner.
    Exactly one row may exist afterwards and both callers must see the same
    `as_of` — otherwise the two instances are back to disagreeing.
    """
    engine = create_engine(integration_settings)
    factory = create_session_factory(engine)
    owner = "race@example.test"

    async def seed(offset: int) -> object:
        async with factory() as session:
            clock = FixedClock(FROZEN_NOW + timedelta(days=offset))
            portfolio = await _provider(session, clock).get(owner)
            await session.commit()
            return portfolio.as_of

    first, second = await asyncio.gather(seed(0), seed(30))

    async with factory() as session:
        stored = await PortfolioRepository(session).find(owner=owner)

    assert stored is not None
    assert first == second == stored.as_of
    await engine.dispose()


async def test_an_owner_never_reads_another_owners_portfolio(
    session: AsyncSession,
) -> None:
    """AC-7 — isolation enforced by the query, not by a later check."""
    clock = FixedClock(FROZEN_NOW)
    await _provider(session, clock).get("owner@example.test")
    await session.commit()

    other = await PortfolioRepository(session).find(owner="stranger@example.test")

    assert other is None
