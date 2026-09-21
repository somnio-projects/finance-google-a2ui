"""The portfolio survives the process, against a real PostgreSQL (spec 0020).

The round-trip half: what is written is what is read. The race and the
isolation live in `test_portfolio_concurrency.py` — they need two sessions,
which is a different fixture and a different question.

Every assertion here needs the database itself: exact `NUMERIC` round-tripping,
a `UNIQUE` constraint deciding a race, and a second provider reading what a
first one wrote. None of it can be faked — a fake repository would agree with
whatever the code does, which is the opposite of the point.
"""

from datetime import timedelta
from decimal import Decimal

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.domain.seed import seed_portfolio
from app.helpers.clock import FixedClock
from app.repositories.portfolio_repository import PortfolioRepository
from app.services.portfolio_service import PersistentPortfolioProvider
from tests.conftest import FROZEN_NOW

pytestmark = pytest.mark.integration


def _provider(session: AsyncSession, clock: FixedClock) -> PersistentPortfolioProvider:
    """Build the production provider over a real session."""
    return PersistentPortfolioProvider(
        repository=PortfolioRepository(session), clock=clock
    )


async def test_a_seeded_portfolio_is_read_back_whole(session: AsyncSession) -> None:
    """AC-1 — what a restart would read is what the first access wrote."""
    clock = FixedClock(FROZEN_NOW)
    written = await _provider(session, clock).get("subject-restart")
    await session.commit()

    # A second provider over the same database is what a second instance is.
    read = await _provider(session, FixedClock(FROZEN_NOW + timedelta(days=9))).get(
        "subject-restart"
    )

    assert read.as_of == written.as_of
    assert [lot.lot_id for lot in read.lots] == sorted(
        lot.lot_id for lot in written.lots
    )
    assert len(read.ledger) == len(written.ledger)
    read.validate()


async def test_two_providers_agree_on_as_of(session: AsyncSession) -> None:
    """AC-2 — the multi-instance divergence, asserted where it lived.

    Before this spec each process seeded from its own clock, so the same
    subject had two `as_of`. The second provider's clock is deliberately far
    from the first's; the answer must still come from the row.
    """
    first = await _provider(session, FixedClock(FROZEN_NOW)).get("subject-two")
    await session.commit()

    later = FixedClock(FROZEN_NOW + timedelta(days=365))
    second = await _provider(session, later).get("subject-two")

    assert second.as_of == first.as_of
    assert second.as_of != later.now()


async def test_positions_are_rebuilt_from_the_lots_not_stored(
    session: AsyncSession,
) -> None:
    """AC-3 — the derivation survives the round trip and still agrees."""
    clock = FixedClock(FROZEN_NOW)
    written = await _provider(session, clock).get("subject-derive")
    await session.commit()

    read = await _provider(session, clock).get("subject-derive")

    read.validate()  # positions still agree with the lots they came from
    assert {holding.symbol for holding in read.positions} == {
        holding.symbol for holding in written.positions
    }
    assert read.total_market_value() == written.total_market_value()


async def test_money_and_quantity_round_trip_exactly(session: AsyncSession) -> None:
    """AC-4 — to the last place, never approximately.

    `pytest.approx` would pass on a value that has silently been through a
    float. That is precisely the defect this column type exists to prevent, so
    the comparison is exact.
    """
    clock = FixedClock(FROZEN_NOW)
    written = await _provider(session, clock).get("subject-exact")
    await session.commit()

    read = await _provider(session, clock).get("subject-exact")

    by_id = {lot.lot_id: lot for lot in written.lots}
    for lot in read.lots:
        original = by_id[lot.lot_id]
        assert lot.quantity == original.quantity
        assert lot.cost_basis == original.cost_basis
        assert isinstance(lot.quantity, Decimal)


async def test_the_second_access_writes_nothing(session: AsyncSession) -> None:
    """AC-5 — seeding happens once, not on every read."""
    clock = FixedClock(FROZEN_NOW)
    repository = PortfolioRepository(session)
    provider = PersistentPortfolioProvider(repository=repository, clock=clock)

    await provider.get("subject-once")
    await session.commit()
    before = await repository.find(subject="subject-once")
    await provider.get("subject-once")
    after = await repository.find(subject="subject-once")

    assert before is not None
    assert after is not None
    assert after.as_of == before.as_of


async def test_the_seed_is_the_curated_demo_portfolio(session: AsyncSession) -> None:
    """What lands in the database is the portfolio the demo was designed around.

    NVDA carries the tax-lot story, AAPL and PYPL the attribution story, VOO the
    order story (spec 0003). A seed that quietly changed would take the three
    flows with it.
    """
    clock = FixedClock(FROZEN_NOW)
    stored = await _provider(session, clock).get("subject-curated")
    await session.commit()

    expected = seed_portfolio(as_of=FROZEN_NOW)
    assert {lot.symbol for lot in stored.lots} == {lot.symbol for lot in expected.lots}
    assert stored.total_market_value() == expected.total_market_value()
