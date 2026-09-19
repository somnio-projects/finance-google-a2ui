import uuid
from datetime import UTC, datetime, timedelta

import pytest
from pytest_mock import MockerFixture
from sqlalchemy import update
from sqlalchemy.exc import OperationalError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import DependencyUnavailableError, NotFoundError
from app.models.audit_event import AuditEvent
from app.repositories.audit_repository import AuditRepository


def _event(subject: str, action: str = "test") -> AuditEvent:
    return AuditEvent(
        subject=subject,
        provider="jwt",
        action=action,
        token_fingerprint="f" * 16,
        request_id=str(uuid.uuid4()),
    )


async def test_add_then_get_round_trips_through_postgres(session: AsyncSession) -> None:
    repo = AuditRepository(session)
    saved = await repo.add(_event(f"s-{uuid.uuid4()}"))
    assert saved.id is not None
    fetched = await repo.get(saved.id)
    assert fetched.subject == saved.subject
    assert fetched.created_at.tzinfo is not None


async def test_get_unknown_id_raises_not_found(session: AsyncSession) -> None:
    missing = uuid.uuid4()
    with pytest.raises(NotFoundError, match=str(missing)):
        await AuditRepository(session).get(missing)


async def test_list_recent_and_list_for_subject_order_newest_first(
    session: AsyncSession,
) -> None:
    repo = AuditRepository(session)
    subject = f"s-{uuid.uuid4()}"
    for action in ("first", "second", "third"):
        await repo.add(_event(subject, action))
    recent = await repo.list_recent(limit=2)
    assert len(recent) == 2
    mine = await repo.list_for_subject(subject, limit=10)
    assert [e.action for e in mine] == ["third", "second", "first"]
    assert await repo.list_for_subject(f"nobody-{uuid.uuid4()}", limit=5) == []


async def test_infrastructure_errors_are_translated(
    session: AsyncSession, mocker: MockerFixture
) -> None:
    repo = AuditRepository(session)
    boom = OperationalError("stmt", {}, Exception("down"))
    mocker.patch.object(session, "flush", side_effect=boom, autospec=True)
    mocker.patch.object(session, "execute", side_effect=boom, autospec=True)
    mocker.patch.object(session, "get", side_effect=boom, autospec=True)
    with pytest.raises(DependencyUnavailableError, match="write failed"):
        await repo.add(_event("x"))
    with pytest.raises(DependencyUnavailableError, match="read failed"):
        await repo.get(uuid.uuid4())
    with pytest.raises(DependencyUnavailableError, match="read failed"):
        await repo.list_recent(limit=1)
    with pytest.raises(DependencyUnavailableError, match="read failed"):
        await repo.list_for_subject("x", limit=1)
    with pytest.raises(DependencyUnavailableError, match="write failed"):
        await repo.purge_older_than(datetime.now(tz=UTC))


async def test_purge_older_than_deletes_only_expired_rows(
    session: AsyncSession,
) -> None:
    repo = AuditRepository(session)
    subject = f"s-{uuid.uuid4()}"
    old = await repo.add(_event(subject, "old"))
    await repo.add(_event(subject, "fresh"))
    await session.execute(
        update(AuditEvent)
        .where(AuditEvent.id == old.id)
        .values(created_at=datetime.now(tz=UTC) - timedelta(days=401))
    )
    purged = await repo.purge_older_than(datetime.now(tz=UTC) - timedelta(days=400))
    assert purged == 1
    assert [e.action for e in await repo.list_for_subject(subject, limit=5)] == [
        "fresh"
    ]
