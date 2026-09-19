"""Real-PostgreSQL fixtures.

A throwaway ``postgres:16-alpine`` container is started once per session via
testcontainers (needs Docker). Set ``TEST_DATABASE_URL`` to reuse an
existing database instead — e.g. the one from ``docker compose up db``.
Migrations run through Alembic exactly as in production.
"""

import os
from collections.abc import AsyncIterator, Iterator

import pytest
from alembic import command
from alembic.config import Config
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncSession
from testcontainers.postgres import PostgresContainer

from app.bootstrap import build_container, create_app
from app.core.config import Settings
from app.helpers.clock import FixedClock
from app.infra.db.engine import create_engine
from app.infra.db.session import create_session_factory, session_scope
from tests.conftest import FROZEN_NOW, FakeReporter, make_settings


@pytest.fixture
async def session(database_url: str) -> AsyncIterator[AsyncSession]:
    """One rolled-back session per test against the migrated database."""
    engine = create_engine(make_settings(database_url=database_url))
    async with session_scope(create_session_factory(engine)) as db_session:
        yield db_session
        await db_session.rollback()
    await engine.dispose()


ALEMBIC_INI = os.path.join(os.path.dirname(__file__), "..", "..", "alembic.ini")


def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    for item in items:
        if "/tests/integration/" in str(item.fspath):
            item.add_marker(pytest.mark.integration)


@pytest.fixture(scope="session")
def database_url() -> Iterator[str]:
    """Yield an asyncpg DSN for a migrated, empty PostgreSQL."""
    external = os.environ.get("TEST_DATABASE_URL")
    if external:
        _migrate(external)
        yield external
        return
    with PostgresContainer("postgres:16-alpine", driver="asyncpg") as postgres:
        url = postgres.get_connection_url()
        _migrate(url)
        yield url


def _migrate(url: str) -> None:
    """Run ``alembic upgrade head`` without leaking the URL into ``os.environ``."""
    config = Config(ALEMBIC_INI)
    config.set_main_option("sqlalchemy.url", url)
    command.upgrade(config, "head")


@pytest.fixture
def integration_settings(database_url: str) -> Settings:
    return make_settings(database_url=database_url, trusted_hosts=["*"])


@pytest.fixture
def integration_reporter() -> FakeReporter:
    return FakeReporter()


@pytest.fixture
def integration_app(
    integration_settings: Settings, integration_reporter: FakeReporter
) -> FastAPI:
    container = build_container(
        integration_settings,
        clock=FixedClock(FROZEN_NOW),
        reporter=integration_reporter,
    )
    return create_app(integration_settings, container=container)


@pytest.fixture
def integration_client(integration_app: FastAPI) -> Iterator[TestClient]:
    with TestClient(integration_app) as client:
        yield client
