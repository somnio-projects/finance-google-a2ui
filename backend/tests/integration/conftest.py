"""Real-PostgreSQL fixtures.

A throwaway ``postgres:16-alpine`` container is started once per session via
testcontainers (needs Docker). Set ``TEST_DATABASE_URL`` to reuse an
existing database instead — e.g. the one from ``docker compose up db``.
Migrations run through Alembic exactly as in production.
"""

import os
import uuid
from collections.abc import AsyncIterator, Iterator

import pytest
from alembic import command
from alembic.config import Config
from fastapi import FastAPI
from fastapi.testclient import TestClient
from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession
from testcontainers.postgres import PostgresContainer

from app.bootstrap import build_container, create_app
from app.core.config import Settings
from app.helpers.clock import FixedClock
from app.infra.db.engine import create_engine
from app.infra.db.session import create_session_factory, session_scope
from tests.conftest import FROZEN_NOW, FakeReporter, make_settings, make_token
from tests.integration.database_cleanup import empty_every_table


@pytest.fixture
async def engine(database_url: str) -> AsyncIterator[AsyncEngine]:
    """One disposable engine per test, shared by the cleanup and the session."""
    created = create_engine(make_settings(database_url=database_url))
    try:
        yield created
    finally:
        await created.dispose()


@pytest.fixture(autouse=True)
async def _empty_database(engine: AsyncEngine) -> None:
    """Hand every integration test an empty database (spec 0047, AC-1/AC-2).

    Autouse and in **setup**, not teardown: a test that commits is the normal
    case here — six of them assert what the database decides *after* a commit —
    so the isolation cannot be the session's rollback. Emptying on the way in
    also means an interrupted run cannot poison the next one, which emptying on
    the way out would not give. Spec 0047 §3 records why over rollback.
    """
    await empty_every_table(engine)


@pytest.fixture
async def session(engine: AsyncEngine) -> AsyncIterator[AsyncSession]:
    """One rolled-back session per test against the migrated database."""
    async with session_scope(create_session_factory(engine)) as db_session:
        yield db_session
        await db_session.rollback()


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


SESSIONS = "/v1/sessions"


def subject_headers(subject: str | None = None) -> dict[str, str]:
    """Bearer header for a fresh (or named) verified subject — spec 0004."""
    token = make_token(subject=subject or f"user-{uuid.uuid4()}", ttl_seconds=10**9)
    return {"Authorization": f"Bearer {token}"}


def open_session(
    client: TestClient, headers: dict[str, str], title: str | None = None
) -> str:
    """Open a session for the caller behind ``headers`` and return its id."""
    created = client.post(SESSIONS, json={"title": title}, headers=headers)
    assert created.status_code == 201, created.text
    return str(created.json()["id"])
