import uuid

import pytest
from pytest_mock import MockerFixture
from sqlalchemy.exc import OperationalError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import DependencyUnavailableError
from app.repositories.feature_flag_repository import FeatureFlagRepository


async def test_upsert_creates_then_updates_and_get_reads_back(
    session: AsyncSession,
) -> None:
    repo = FeatureFlagRepository(session)
    key = f"it.{uuid.uuid4().hex[:8]}"
    assert await repo.get(key) is None
    created = await repo.upsert(key, enabled=False, description="first", updated_by="a")
    assert (created.enabled, created.description, created.updated_by) == (
        False,
        "first",
        "a",
    )
    assert created.updated_at is not None
    updated = await repo.upsert(key, enabled=True, description=None, updated_by="b")
    assert (updated.enabled, updated.description, updated.updated_by) == (
        True,
        "first",
        "b",
    )
    fetched = await repo.get(key)
    assert fetched is not None and fetched.enabled is True
    assert any(f.key == key for f in await repo.list_all())


async def test_infrastructure_errors_are_translated(
    session: AsyncSession, mocker: MockerFixture
) -> None:
    repo = FeatureFlagRepository(session)
    boom = OperationalError("stmt", {}, Exception("down"))
    mocker.patch.object(session, "get", side_effect=boom, autospec=True)
    mocker.patch.object(session, "execute", side_effect=boom, autospec=True)
    with pytest.raises(DependencyUnavailableError, match="read failed"):
        await repo.get("x")
    with pytest.raises(DependencyUnavailableError, match="read failed"):
        await repo.list_all()
    with pytest.raises(DependencyUnavailableError, match="write failed"):
        await repo.upsert("x", enabled=True, description=None, updated_by="a")
