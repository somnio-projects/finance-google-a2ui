"""AC-8 — every portfolio access goes through the provider, per subject.

`InMemoryPortfolioProvider` is the **test double** since spec 0020; the
production path is `PersistentPortfolioProvider` over PostgreSQL. These tests
still earn their place: they pin the Protocol's contract — seed once, keep
`as_of`, never let two subjects share an object — which both implementations
must satisfy.
"""

from datetime import timedelta

from app.domain.portfolio import Portfolio
from app.domain.provider import InMemoryPortfolioProvider, PortfolioProvider
from app.helpers.clock import FixedClock
from tests.conftest import FROZEN_NOW


async def test_provider_seeds_on_first_access_and_is_stable(clock: FixedClock) -> None:
    provider = InMemoryPortfolioProvider(clock=clock)
    first = await provider.get("subject-a")
    assert first.as_of == FROZEN_NOW
    first.validate()
    clock.advance(timedelta(days=400))
    assert await provider.get("subject-a") is first


async def test_two_subjects_get_independent_portfolios(clock: FixedClock) -> None:
    provider = InMemoryPortfolioProvider(clock=clock)
    one = await provider.get("subject-a")
    clock.advance(timedelta(days=10))
    other = await provider.get("subject-b")
    assert one is not other
    assert other.as_of == FROZEN_NOW + timedelta(days=10)


async def test_saved_portfolio_replaces_the_previous_one_for_that_subject_only(
    clock: FixedClock,
) -> None:
    provider: PortfolioProvider = InMemoryPortfolioProvider(clock=clock)
    untouched = await provider.get("subject-b")
    mutated = Portfolio(
        as_of=untouched.as_of,
        positions=untouched.positions,
        lots=untouched.lots,
        ledger=untouched.ledger[:1],
    )
    await provider.save("subject-a", mutated)
    assert await provider.get("subject-a") is mutated
    assert await provider.get("subject-b") is untouched
    untouched.validate()
    mutated.validate()
