"""The persistent provider's decisions, without a database (spec 0020).

What is worth asserting here is not "it calls the repository" — that is the
implementation restated. It is the three judgements the provider makes on its
own: seed only on a miss, take `as_of` from the **row** rather than the clock,
and resolve a lost race by re-reading instead of retrying the write.

The database half (AC-1…AC-7) is in `tests/integration/test_portfolio_repository.py`,
where a real PostgreSQL can enforce the unique constraint this relies on.
"""

from datetime import timedelta

import pytest
from sqlalchemy.exc import IntegrityError

from app.core.errors import DependencyUnavailableError
from app.domain.portfolio import Portfolio
from app.domain.seed import seed_portfolio
from app.helpers.clock import FixedClock
from tests.conftest import FROZEN_NOW
from tests.unit.services.portfolio_fakes import FakeRepository, provider


async def test_a_stored_portfolio_is_returned_without_seeding(
    clock: FixedClock,
) -> None:
    stored = seed_portfolio(as_of=FROZEN_NOW)
    repository = FakeRepository(stored=stored)

    returned = await provider(repository, clock).get("subject-a")

    assert returned is stored
    assert repository.writes == 0


async def test_as_of_comes_from_the_row_not_from_the_clock(
    clock: FixedClock,
) -> None:
    """The defect this whole spec exists to fix, asserted directly.

    A second process reading an existing portfolio must report the instant it
    was seeded at, not the instant *it* happens to be running at. That is what
    made one subject have two `as_of` across two instances.
    """
    stored = seed_portfolio(as_of=FROZEN_NOW)
    clock.advance(timedelta(days=30))

    returned = await provider(FakeRepository(stored=stored), clock).get("subject-a")

    assert returned.as_of == FROZEN_NOW
    assert returned.as_of != clock.now()


async def test_a_missing_portfolio_is_seeded_and_written_once(
    clock: FixedClock,
) -> None:
    repository = FakeRepository()

    returned = await provider(repository, clock).get("subject-a")

    assert returned.as_of == FROZEN_NOW
    assert repository.writes == 1
    returned.validate()


async def test_a_freshly_seeded_portfolio_is_read_back_not_returned_directly(
    clock: FixedClock,
) -> None:
    """The first answer of a session must equal every answer after it.

    `NUMERIC(38, 18)` returns a `Decimal` with eighteen places; the seeded
    object has whatever the arithmetic produced. Returning the seeded one
    would make the first response's raw `value` strings differ from the
    second's, which ADR-K D-20 forbids — the integration flow test found it.
    """
    repository = FakeRepository()

    returned = await provider(repository, clock).get("subject-a")

    assert returned is repository.stored


async def test_a_lost_race_re_reads_the_winner_instead_of_retrying(
    clock: FixedClock,
) -> None:
    """Two instances seeding one subject converge on the winner's portfolio.

    The loser must not write again — a retry would either duplicate or fail
    forever. It reads what the winner stored, which is only safe because
    `uq_portfolios_subject` guarantees there is exactly one.
    """
    winner = seed_portfolio(as_of=FROZEN_NOW - timedelta(days=5))
    repository = FakeRepository(conflict=winner)

    returned = await provider(repository, clock).get("subject-a")

    assert returned is winner
    assert repository.writes == 1


async def test_a_lost_race_whose_winner_vanished_is_reported_not_guessed(
    clock: FixedClock,
) -> None:
    """The branch that cannot happen, which is why it must not be silent."""

    class Vanishing(FakeRepository):
        async def find(self, *, subject: str) -> Portfolio | None:
            del subject
            return None

        async def replace(self, *, subject: str, portfolio: Portfolio) -> None:
            del subject, portfolio
            self.writes += 1
            raise IntegrityError("insert", (), Exception("duplicate subject"))

    with pytest.raises(DependencyUnavailableError, match="could not be created"):
        await provider(Vanishing(), clock).get("subject-a")


async def test_save_replaces_through_the_repository(clock: FixedClock) -> None:
    repository = FakeRepository()
    portfolio = seed_portfolio(as_of=FROZEN_NOW)

    await provider(repository, clock).save("subject-a", portfolio)

    assert repository.stored is portfolio
    assert repository.writes == 1
