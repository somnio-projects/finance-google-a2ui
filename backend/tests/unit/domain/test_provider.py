"""AC-8 — every portfolio access goes through the provider, per subject."""

from datetime import timedelta

from app.domain.portfolio import Portfolio
from app.domain.provider import InMemoryPortfolioProvider, PortfolioProvider
from app.helpers.clock import FixedClock
from tests.conftest import FROZEN_NOW


def test_provider_seeds_on_first_access_and_is_stable(clock: FixedClock) -> None:
    provider = InMemoryPortfolioProvider(clock=clock)
    first = provider.get("subject-a")
    assert first.as_of == FROZEN_NOW
    first.validate()
    clock.advance(timedelta(days=400))
    assert provider.get("subject-a") is first


def test_two_subjects_get_independent_portfolios(clock: FixedClock) -> None:
    provider = InMemoryPortfolioProvider(clock=clock)
    one = provider.get("subject-a")
    clock.advance(timedelta(days=10))
    other = provider.get("subject-b")
    assert one is not other
    assert other.as_of == FROZEN_NOW + timedelta(days=10)


def test_saved_portfolio_replaces_the_previous_one_for_that_subject_only(
    clock: FixedClock,
) -> None:
    provider: PortfolioProvider = InMemoryPortfolioProvider(clock=clock)
    untouched = provider.get("subject-b")
    mutated = Portfolio(
        as_of=untouched.as_of,
        positions=untouched.positions,
        lots=untouched.lots,
        ledger=untouched.ledger[:1],
    )
    provider.save("subject-a", mutated)
    assert provider.get("subject-a") is mutated
    assert provider.get("subject-b") is untouched
    untouched.validate()
    mutated.validate()
