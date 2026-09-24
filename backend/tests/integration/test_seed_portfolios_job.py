"""The seed job against a real PostgreSQL (spec 0035 §4.1, AC-2, AC-10).

Two claims can only be checked here, because both are the database's:
``uq_portfolios_owner_email`` deciding that one e-mail is one row, and the
job's "skip what exists" behaving the same way after a commit as it does
against a dict.
"""

import pytest
from sqlalchemy.ext.asyncio import AsyncSession

from app.bootstrap import build_container
from app.core.config import Settings
from app.core.principal import Principal
from app.helpers.clock import FixedClock
from app.jobs.seed_portfolios import seed, seed_into
from app.repositories.portfolio_repository import PortfolioRepository
from app.services.portfolio_service import PersistentPortfolioProvider
from tests.conftest import FROZEN_NOW

pytestmark = pytest.mark.integration

AUDIENCE = ["first@example.test", "second@example.test"]


def _principal(*, subject: str, email: str) -> Principal:
    return Principal(
        subject=subject, provider="oidc", email=email, token_fingerprint="f" * 16
    )


async def test_one_run_seeds_a_whole_audience(session: AsyncSession) -> None:
    """AC-10: several addresses, one invocation."""
    repository = PortfolioRepository(session)

    seeded, skipped = await seed_into(
        repository, owners=AUDIENCE, reset=False, as_of=FROZEN_NOW
    )
    await session.commit()

    assert (seeded, skipped) == (2, 0)
    for owner in AUDIENCE:
        stored = await repository.find(owner=owner)
        assert stored is not None
        assert stored.as_of == FROZEN_NOW


async def test_running_it_again_writes_nothing_and_resetting_does(
    session: AsyncSession,
) -> None:
    """AC-10: safe to re-run over an overlapping list; `--reset` is opt-in."""
    repository = PortfolioRepository(session)
    await seed_into(
        repository, owners=["again@example.test"], reset=False, as_of=FROZEN_NOW
    )
    await session.commit()

    second = await seed_into(
        repository, owners=["again@example.test"], reset=False, as_of=FROZEN_NOW
    )
    later = FROZEN_NOW.replace(year=FROZEN_NOW.year + 1)
    reset = await seed_into(
        repository, owners=["again@example.test"], reset=True, as_of=later
    )
    await session.commit()

    assert (second, reset) == ((0, 1), (1, 0))
    stored = await repository.find(owner="again@example.test")
    assert stored is not None
    assert stored.as_of == later


async def test_two_subjects_with_one_email_read_the_seeded_portfolio(
    session: AsyncSession,
) -> None:
    """AC-2: the job seeds an owner, and both of their tokens find it."""
    repository = PortfolioRepository(session)
    await seed_into(
        repository, owners=["shared@example.test"], reset=False, as_of=FROZEN_NOW
    )
    await session.commit()

    provider = PersistentPortfolioProvider(
        repository=repository, clock=FixedClock(FROZEN_NOW.replace(day=1))
    )
    google = _principal(subject="uid-google", email="Shared@Example.Test")
    password = _principal(subject="uid-password", email="shared@example.test")

    first = await provider.get(google.owner_key)
    second = await provider.get(password.owner_key)

    # The same row, not two seeded copies: `as_of` is the job's, not the
    # provider's clock, which is only true if neither call seeded anything.
    assert first.as_of == second.as_of == FROZEN_NOW


async def test_a_different_email_gets_its_own_portfolio(
    session: AsyncSession,
) -> None:
    """OD-2: an unseeded caller gets their own copy, not somebody else's row."""
    repository = PortfolioRepository(session)
    await seed_into(
        repository, owners=["owner@example.test"], reset=False, as_of=FROZEN_NOW
    )
    await session.commit()

    stranger = await repository.find(owner="stranger@example.test")
    assert stranger is None

    provider = PersistentPortfolioProvider(
        repository=repository, clock=FixedClock(FROZEN_NOW)
    )
    made = await provider.get("stranger@example.test")
    await session.commit()

    owned = await repository.find(owner="owner@example.test")
    assert owned is not None
    assert made.total_market_value() == owned.total_market_value()
    assert await repository.find(owner="stranger@example.test") is not None


async def test_the_job_seeds_end_to_end_through_its_own_session(
    integration_settings: Settings,
) -> None:
    """The entry point, not just its loop: it opens a session and commits.

    `seed_into` is exercised above against a test-owned session. This runs
    the function the Cloud Run job actually calls, so the `session_scope`
    around it — and the commit that scope owns — is the thing under test.
    """
    container = build_container(integration_settings)
    owners = ["endtoend@example.test"]
    try:
        first = await seed(container, owners=owners, reset=False)
        second = await seed(container, owners=owners, reset=False)
    finally:
        await container.engine.dispose()

    assert (first, second) == ((1, 0), (0, 1))
