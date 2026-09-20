"""Fixtures for the presentation suite (spec 0005).

Everything is rendered at the frozen ``as_of`` the rest of the unit suite
uses, so the numbers in these assertions are stable literals rather than
whatever the calendar says today.
"""

from collections.abc import Iterator
from decimal import Decimal
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

from app.core.principal import Principal
from app.domain.holdings import Holding
from app.domain.portfolio import Portfolio
from app.domain.seed import seed_portfolio
from app.helpers.clock import FixedClock
from app.presentation.registry import ProjectionRegistry
from tests.conftest import FROZEN_NOW, FakeReporter, make_settings
from tests.unit.api.conftest import UNREACHABLE_DSN, make_views_client

REPO_ROOT = Path(__file__).resolve().parents[4]


def committed(path: str) -> str:
    """Return a generated artefact as checked in, or "" when it is missing."""
    target = REPO_ROOT / path
    return target.read_text(encoding="utf-8") if target.exists() else ""


def make_holding(
    *, symbol: str, name: str, value: str, cost: str, weight: str
) -> Holding:
    """Build one hand-made, invariant-clean holding at a nominal price of 1."""
    return Holding(
        symbol=symbol,
        name=name,
        quantity=Decimal(value),
        price=Decimal(1),
        market_value=Decimal(value),
        cost_basis=Decimal(cost),
        unrealized_pl=Decimal(value) - Decimal(cost),
        weight=Decimal(weight),
    )


def make_portfolio(*holdings: Holding) -> Portfolio:
    """Wrap ``holdings`` in a portfolio at the frozen ``as_of``."""
    return Portfolio(as_of=FROZEN_NOW, positions=holdings, lots=(), ledger=())


@pytest.fixture
def portfolio() -> Portfolio:
    """The curated seed, built at the frozen ``as_of``."""
    return seed_portfolio(as_of=FROZEN_NOW)


@pytest.fixture
def winners_only() -> Portfolio:
    """A portfolio where every holding is up — nothing to attribute."""
    return make_portfolio(
        make_holding(symbol="AAA", name="Alpha", value="60", cost="40", weight="0.6"),
        make_holding(symbol="BBB", name="Beta", value="40", cost="30", weight="0.4"),
    )


@pytest.fixture
def empty_portfolio() -> Portfolio:
    """A portfolio with nothing in it — no projection fits."""
    return make_portfolio()


@pytest.fixture
def registry() -> ProjectionRegistry:
    """An empty registry, isolated from the process-wide one."""
    return ProjectionRegistry()


@pytest.fixture
def views_client(principal: Principal) -> Iterator[TestClient]:
    """The real app with the view feature gates faked on, for catalog reads."""
    settings = make_settings(
        database_url=UNREACHABLE_DSN, trusted_hosts=["testserver", "localhost"]
    )
    yield from make_views_client(
        settings,
        principal=principal,
        clock=FixedClock(FROZEN_NOW),
        reporter=FakeReporter(),
    )
