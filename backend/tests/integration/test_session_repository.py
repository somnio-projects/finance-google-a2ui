"""``SessionRepository`` against real PostgreSQL (spec 0004 AC-4, AC-9)."""

import uuid

import pytest
from pytest_mock import MockerFixture
from sqlalchemy import func, select
from sqlalchemy.exc import OperationalError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.errors import DependencyUnavailableError
from app.helpers.cursor import encode_cursor
from app.models.conversation_message import ConversationMessage
from app.repositories.session_repository import SessionRepository


async def _open(repo: SessionRepository, subject: str) -> uuid.UUID:
    created = await repo.create(subject=subject, provider="jwt", title=None)
    return created.id


async def test_create_and_get_are_scoped_to_the_owning_subject(
    session: AsyncSession,
) -> None:
    repo = SessionRepository(session)
    owner = f"owner-{uuid.uuid4()}"
    session_id = await _open(repo, owner)

    assert (await repo.get_for_subject(session_id, owner)) is not None
    assert (await repo.get_for_subject(session_id, f"other-{uuid.uuid4()}")) is None
    assert (await repo.get_for_subject(uuid.uuid4(), owner)) is None


async def test_delete_is_scoped_and_cascades_to_messages(
    session: AsyncSession,
) -> None:
    repo = SessionRepository(session)
    owner = f"owner-{uuid.uuid4()}"
    session_id = await _open(repo, owner)
    await repo.add_message(session_id, role="user", content="secret")

    assert await repo.delete_for_subject(session_id, f"other-{uuid.uuid4()}") is False
    assert (await repo.get_for_subject(session_id, owner)) is not None

    assert await repo.delete_for_subject(session_id, owner) is True
    assert await repo.delete_for_subject(session_id, owner) is False
    left = await session.execute(
        select(func.count())
        .select_from(ConversationMessage)
        .where(ConversationMessage.session_id == session_id)
    )
    assert left.scalar_one() == 0


async def test_keyset_cursor_walks_sessions_and_messages_without_repeats(
    session: AsyncSession,
) -> None:
    repo = SessionRepository(session)
    owner = f"owner-{uuid.uuid4()}"
    for _ in range(3):
        await _open(repo, owner)

    head = await repo.list_for_subject(owner, limit=2, after=None)
    assert len(head) == 2
    tail = await repo.list_for_subject(
        owner, limit=2, after=(head[1].created_at, head[1].id)
    )
    assert len(tail) == 1
    assert {row.id for row in tail}.isdisjoint({row.id for row in head})
    assert encode_cursor(head[1].created_at, head[1].id)

    conversation = head[0].id
    for turn in ("a", "b", "c"):
        await repo.add_message(conversation, role="user", content=turn)
    # Rows written inside one transaction share ``now()``, so this exercises the
    # id half of the ``(created_at, id)`` keyset; ordering by time is asserted in
    # ``test_session_flow.py``, where each turn is its own request.
    first = await repo.list_messages(conversation, limit=2, after=None)
    assert len(first) == 2
    rest = await repo.list_messages(
        conversation, limit=2, after=(first[1].created_at, first[1].id)
    )
    assert {m.content for m in first} | {m.content for m in rest} == {"a", "b", "c"}


async def test_infrastructure_errors_are_translated(
    session: AsyncSession, mocker: MockerFixture
) -> None:
    repo = SessionRepository(session)
    boom = OperationalError("stmt", {}, Exception("down"))
    mocker.patch.object(session, "flush", side_effect=boom, autospec=True)
    mocker.patch.object(session, "execute", side_effect=boom, autospec=True)

    with pytest.raises(DependencyUnavailableError, match="write failed"):
        await repo.create(subject="s", provider="jwt", title=None)
    with pytest.raises(DependencyUnavailableError, match="write failed"):
        await repo.add_message(uuid.uuid4(), role="user", content="x")
    with pytest.raises(DependencyUnavailableError, match="read failed"):
        await repo.get_for_subject(uuid.uuid4(), "s")
    with pytest.raises(DependencyUnavailableError, match="read failed"):
        await repo.list_for_subject("s", limit=1, after=None)
    with pytest.raises(DependencyUnavailableError, match="read failed"):
        await repo.list_messages(uuid.uuid4(), limit=1, after=None)
    with pytest.raises(DependencyUnavailableError, match="write failed"):
        await repo.delete_for_subject(uuid.uuid4(), "s")
