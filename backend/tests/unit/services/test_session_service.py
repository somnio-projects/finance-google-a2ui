"""Subject scoping of the session use cases (spec 0004 AC-1..AC-4, AC-8)."""

import pytest

from app.core.errors import NotFoundError, ValidationFailedError
from app.core.principal import Principal
from app.helpers.cursor import decode_cursor
from app.schemas.messages import MessageCreate
from app.services.session_service import SessionService
from tests.unit.services.conftest import FakeSessionRepository, RecordingAudit


async def test_create_persists_owner_from_principal_and_audits(
    service: SessionService,
    repository: FakeSessionRepository,
    audit: RecordingAudit,
    principal: Principal,
) -> None:
    created = await service.create(principal, title="Review", request_id="req-1")
    stored = repository.sessions[0]
    assert stored.subject == principal.subject
    assert stored.provider == principal.provider
    assert created.id == stored.id
    assert created.title == "Review"
    assert audit.calls == [("session.create", str(created.id), "req-1")]


async def test_reads_of_another_subject_raise_not_found(
    service: SessionService, principal: Principal, other: Principal
) -> None:
    mine = await service.create(principal, title=None, request_id="req-1")
    for call in (
        service.get(other, mine.id, request_id="r"),
        service.list_messages(other, mine.id, limit=10, cursor=None, request_id="r"),
        service.append_message(
            other,
            mine.id,
            message=MessageCreate(role="user", content="hi"),
            request_id="r",
        ),
    ):
        with pytest.raises(NotFoundError, match=str(mine.id)):
            await call


async def test_delete_of_another_subject_raises_not_found(
    service: SessionService,
    repository: FakeSessionRepository,
    principal: Principal,
    other: Principal,
) -> None:
    mine = await service.create(principal, title=None, request_id="req-1")
    with pytest.raises(NotFoundError, match=str(mine.id)):
        await service.delete(other, mine.id, request_id="r")
    assert repository.sessions  # the owner's session is untouched


async def test_delete_removes_own_session_and_audits(
    service: SessionService,
    repository: FakeSessionRepository,
    audit: RecordingAudit,
    principal: Principal,
) -> None:
    mine = await service.create(principal, title=None, request_id="req-1")
    await service.delete(principal, mine.id, request_id="req-2")
    assert repository.sessions == []
    assert audit.calls[-1] == ("session.delete", str(mine.id), "req-2")
    with pytest.raises(NotFoundError, match=str(mine.id)):
        await service.delete(principal, mine.id, request_id="req-3")


async def test_get_returns_the_callers_own_session_and_audits(
    service: SessionService, audit: RecordingAudit, principal: Principal
) -> None:
    mine = await service.create(principal, title="Mine", request_id="req-1")
    read = await service.get(principal, mine.id, request_id="req-2")
    assert read.id == mine.id
    assert audit.calls[-1] == ("session.read", str(mine.id), "req-2")


async def test_list_sessions_pages_with_cursor_and_scopes_by_subject(
    service: SessionService,
    repository: FakeSessionRepository,
    audit: RecordingAudit,
    principal: Principal,
    other: Principal,
) -> None:
    mine = [
        await service.create(principal, title=str(n), request_id="r") for n in range(3)
    ]
    await service.create(other, title="theirs", request_id="r")

    first = await service.list_sessions(
        principal, limit=2, cursor=None, request_id="req-2"
    )
    assert [item.id for item in first.items] == [mine[0].id, mine[1].id]
    assert repository.asked[-1] == (3, None)  # limit + 1, to know there is more
    assert first.next_cursor is not None
    assert decode_cursor(first.next_cursor) == (mine[1].created_at, mine[1].id)
    assert audit.calls[-1] == ("session.list", None, "req-2")

    last = await service.list_sessions(
        principal, limit=10, cursor=first.next_cursor, request_id="r"
    )
    assert repository.asked[-1] == (11, (mine[1].created_at, mine[1].id))
    assert last.next_cursor is None
    assert {item.id for item in last.items} <= {s.id for s in mine}


async def test_an_unusable_cursor_is_rejected_before_the_repository(
    service: SessionService, repository: FakeSessionRepository, principal: Principal
) -> None:
    with pytest.raises(ValidationFailedError, match="not a valid pagination cursor"):
        await service.list_sessions(
            principal, limit=10, cursor="not-a-cursor!!", request_id="r"
        )
    assert repository.asked == []
