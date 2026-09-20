"""Build the real FastAPI app with in-memory doubles (no database traffic).

The DSN points at port 1 so any accidental connection is refused instantly;
routes that need the database are covered by ``tests/integration``.
"""

from collections.abc import Iterator

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.deps import get_feature_flag_service
from app.core.config import Settings
from app.core.principal import Principal
from app.helpers.clock import FixedClock
from tests.conftest import FakeFlags, FakeReporter, make_settings
from tests.unit.api.app_factory import make_app

UNREACHABLE_DSN = "postgresql+asyncpg://app:app@127.0.0.1:1/nowhere"


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


def make_session_app(
    principal: Principal,
    clock: FixedClock,
    reporter: FakeReporter,
    **overrides: object,
) -> FastAPI:
    """App for the session routes (spec 0004) with room for several requests."""
    settings = make_settings(
        database_url=UNREACHABLE_DSN,
        rate_limit_per_minute=200,
        trusted_hosts=["testserver", "localhost"],
        **overrides,
    )
    return make_app(settings, principal=principal, clock=clock, reporter=reporter)


@pytest.fixture
def sessions_client(
    principal: Principal, clock: FixedClock, reporter: FakeReporter
) -> Iterator[TestClient]:
    app = make_session_app(principal, clock, reporter)
    with TestClient(app, raise_server_exceptions=False) as test_client:
        yield test_client
