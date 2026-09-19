"""Message use cases of ``SessionService`` (spec 0004 AC-5, AC-6)."""

from app.core.principal import Principal
from app.helpers.cursor import decode_cursor
from app.schemas.messages import MessageCreate
from app.services.session_service import SessionService
from tests.unit.services.conftest import FakeSessionRepository, RecordingAudit


async def test_append_message_audits_with_target(
    service: SessionService,
    repository: FakeSessionRepository,
    audit: RecordingAudit,
    principal: Principal,
) -> None:
    mine = await service.create(principal, title=None, request_id="r")
    appended = await service.append_message(
        principal,
        mine.id,
        message=MessageCreate(role="assistant", content="4.2 % this quarter"),
        request_id="req-9",
    )
    assert appended.session_id == mine.id
    assert appended.role == "assistant"
    assert repository.messages[0].content == "4.2 % this quarter"
    assert audit.calls[-1] == ("session.append", str(mine.id), "req-9")


async def test_list_messages_pages_oldest_first(
    service: SessionService,
    repository: FakeSessionRepository,
    audit: RecordingAudit,
    principal: Principal,
) -> None:
    mine = await service.create(principal, title=None, request_id="r")
    for turn in ("first", "second", "third"):
        await service.append_message(
            principal,
            mine.id,
            message=MessageCreate(role="user", content=turn),
            request_id="r",
        )
    page = await service.list_messages(
        principal, mine.id, limit=2, cursor=None, request_id="req-3"
    )
    assert [m.content for m in page.items] == ["first", "second"]
    assert page.next_cursor is not None
    assert audit.calls[-1] == ("session.read", str(mine.id), "req-3")

    tail = await service.list_messages(
        principal, mine.id, limit=5, cursor=page.next_cursor, request_id="r"
    )
    assert tail.next_cursor is None
    # The decoded cursor is what reaches the repository, unchanged.
    assert repository.asked[-1] == (6, decode_cursor(page.next_cursor))
