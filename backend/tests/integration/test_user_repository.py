"""``UserRepository`` and the bootstrap against real PostgreSQL (spec 0027)."""

import uuid

import pytest
from pytest_mock import MockerFixture
from sqlalchemy.exc import OperationalError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import DependencyUnavailableError
from app.infra.db.engine import create_engine
from app.infra.db.session import create_session_factory
from app.repositories.user_repository import UserRepository
from app.services.user_bootstrap import provision_admins
from tests.conftest import FROZEN_NOW, make_settings


def _email() -> str:
    return f"user-{uuid.uuid4()}@example.test"


async def test_upsert_creates_then_moves_and_keeps_the_name(
    session: AsyncSession,
) -> None:
    repo = UserRepository(session)
    email = _email()
    assert await repo.find_by_email(email) is None
    created = await repo.upsert(
        email=email,
        display_name="Alex",
        role="member",
        status="requested",
        invited_by=None,
    )
    moved = await repo.upsert(
        email=email,
        display_name=None,
        role="member",
        status="invited",
        invited_by="root@somnio.dev",
    )
    assert moved.id == created.id
    assert (moved.status, moved.display_name, moved.invited_by) == (
        "invited",
        "Alex",
        "root@somnio.dev",
    )
    seen = await repo.touch(moved, seen_at=FROZEN_NOW, status="active")
    assert (seen.status, seen.last_seen_at) == ("active", FROZEN_NOW)
    assert await repo.touch(seen, seen_at=FROZEN_NOW) is seen
    listed = await repo.list_all(limit=500)
    assert email in {row.email for row in listed}


async def test_read_failures_become_a_typed_503(
    session: AsyncSession, mocker: MockerFixture
) -> None:
    boom = OperationalError("stmt", {}, Exception("down"))
    mocker.patch.object(session, "execute", side_effect=boom, autospec=True)
    repo = UserRepository(session)
    with pytest.raises(DependencyUnavailableError):
        await repo.find_by_email("a@example.test")
    with pytest.raises(DependencyUnavailableError):
        await repo.list_all(limit=1)


async def test_write_failures_become_a_typed_503(
    session: AsyncSession, mocker: MockerFixture
) -> None:
    # Only the write fails: the read inside ``upsert`` succeeds, so it is the
    # write path's own translation that answers, not the read's.
    boom = OperationalError("stmt", {}, Exception("down"))
    mocker.patch.object(session, "flush", side_effect=boom, autospec=True)
    repo = UserRepository(session)
    with pytest.raises(DependencyUnavailableError):
        await repo.upsert(
            email=_email(),
            display_name=None,
            role="member",
            status="invited",
            invited_by=None,
        )
    row = type("Row", (), {"last_seen_at": None, "status": "invited"})()
    with pytest.raises(DependencyUnavailableError):
        await repo.touch(row, seen_at=FROZEN_NOW)  # pyright: ignore[reportArgumentType]


async def test_bootstrap_admins_land_and_are_idempotent(database_url: str) -> None:
    engine = create_engine(make_settings(database_url=database_url))
    factory = create_session_factory(engine)
    email = _email()
    try:
        assert await provision_admins(emails=[email], session_factory=factory) == 1
        assert await provision_admins(emails=[email], session_factory=factory) == 0
    finally:
        await engine.dispose()
