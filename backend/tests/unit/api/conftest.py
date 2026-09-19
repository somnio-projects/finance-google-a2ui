"""Build the real FastAPI app with in-memory doubles (no database traffic).

The DSN points at port 1 so any accidental connection is refused instantly;
routes that need the database are covered by ``tests/integration``.
"""

from collections.abc import Iterator
from datetime import timedelta

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.container import Container
from app.bootstrap import create_app
from app.core.config import Settings
from app.core.principal import Principal
from app.helpers.clock import FixedClock
from app.infra.db.engine import DatabaseReadinessProbe, create_engine
from app.infra.db.session import create_session_factory
from app.services.feature_flag_cache import FeatureFlagCache
from app.services.health_service import HealthService
from tests.conftest import FakeReporter, FakeVerifier, make_settings

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
    container = Container(
        settings=settings,
        clock=clock,
        reporter=reporter,
        verifier=FakeVerifier(principal),
        engine=engine,
        session_factory=create_session_factory(engine),
        health=HealthService(version="test", probes=[DatabaseReadinessProbe(engine)]),
        flag_cache=FeatureFlagCache(ttl=timedelta(seconds=15), clock=clock),
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
