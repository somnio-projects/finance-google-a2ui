"""Build the real FastAPI app with in-memory doubles (no database traffic).

The DSN points at port 1 so any accidental connection is refused instantly;
routes that need the database are covered by ``tests/integration``.
"""

from collections.abc import Iterator
from datetime import timedelta

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.agent.registry import load_tools
from app.api.container import AgentRuntime, Container
from app.api.deps import get_feature_flag_service
from app.bootstrap import create_app
from app.core.config import Settings
from app.core.principal import Principal
from app.domain.provider import InMemoryPortfolioProvider
from app.helpers.clock import FixedClock
from app.infra.db.engine import DatabaseReadinessProbe, create_engine
from app.infra.db.session import create_session_factory
from app.infra.model.null_client import NullModelClient
from app.presentation.registry import REGISTRY
from app.services.agent_card_service import build_agent_card
from app.services.feature_flag_cache import FeatureFlagCache
from app.services.health_service import HealthService
from app.services.prompt_service import build_system_prompt
from tests.conftest import FakeFlags, FakeReporter, FakeVerifier, make_settings

UNREACHABLE_DSN = "postgresql+asyncpg://app:app@127.0.0.1:1/nowhere"


def make_app(
    settings: Settings,
    *,
    principal: Principal,
    clock: FixedClock,
    reporter: FakeReporter,
) -> FastAPI:
    """Create the app with a fake verifier accepting the token ``good``."""
    engine = create_engine(settings)
    tools = load_tools()
    container = Container(
        settings=settings,
        clock=clock,
        reporter=reporter,
        verifier=FakeVerifier(principal),
        engine=engine,
        session_factory=create_session_factory(engine),
        health=HealthService(version="test", probes=[DatabaseReadinessProbe(engine)]),
        flag_cache=FeatureFlagCache(ttl=timedelta(seconds=15), clock=clock),
        agent=AgentRuntime(
            model=NullModelClient(),
            tools=tools,
            system_prompt=build_system_prompt(tools=tools, views=REGISTRY.all()),
            card=build_agent_card(settings, tools, version="test"),
        ),
        portfolio=InMemoryPortfolioProvider(clock=clock),
    )
    return create_app(settings, container=container)


@pytest.fixture
def api_settings() -> Settings:
    return make_settings(
        database_url=UNREACHABLE_DSN,
        rate_limit_per_minute=3,
        max_request_body_bytes=2048,
        trusted_hosts=["testserver", "localhost"],
    )


@pytest.fixture
def app(
    api_settings: Settings,
    principal: Principal,
    clock: FixedClock,
    reporter: FakeReporter,
) -> FastAPI:
    return make_app(api_settings, principal=principal, clock=clock, reporter=reporter)


@pytest.fixture
def client(app: FastAPI) -> Iterator[TestClient]:
    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client


@pytest.fixture
def unlimited_app(
    principal: Principal, clock: FixedClock, reporter: FakeReporter
) -> FastAPI:
    """An app whose rate limiter will not fire during a test.

    The default fixture limits to 3 requests a minute so the limiter itself can
    be tested. A test that sweeps every route needs the opposite, and would
    otherwise get a 429 and read it as "guarded" — which is exactly the false
    green an auth sweep must not have.
    """
    settings = make_settings(
        database_url=UNREACHABLE_DSN,
        rate_limit_per_minute=10_000,
        max_request_body_bytes=2048,
        trusted_hosts=["testserver", "localhost"],
    )
    return make_app(settings, principal=principal, clock=clock, reporter=reporter)


@pytest.fixture
def unlimited_client(unlimited_app: FastAPI) -> Iterator[TestClient]:
    with TestClient(unlimited_app, raise_server_exceptions=False) as test_client:
        yield test_client


def make_views_client(
    settings: Settings,
    *,
    principal: Principal,
    clock: FixedClock,
    reporter: FakeReporter,
) -> Iterator[TestClient]:
    """Yield a client for the view routes with their feature gates faked on.

    The gates read the flag service, which reads the database; the view
    routes themselves touch neither, so the fake keeps this a unit test.
    """
    app = make_app(settings, principal=principal, clock=clock, reporter=reporter)
    app.dependency_overrides[get_feature_flag_service] = FakeFlags
    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client
    app.dependency_overrides.clear()


@pytest.fixture
def views_client(
    api_settings: Settings,
    principal: Principal,
    clock: FixedClock,
    reporter: FakeReporter,
) -> Iterator[TestClient]:
    yield from make_views_client(
        api_settings, principal=principal, clock=clock, reporter=reporter
    )
