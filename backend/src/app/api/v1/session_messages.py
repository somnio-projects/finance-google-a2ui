"""Message sub-resource of a conversation session (spec 0004, GGU-46).

A message is only ever reachable through its session, and the session is
resolved for the caller's subject first — so these routes inherit the
isolation of `/v1/sessions/{session_id}` without restating it.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, status

from app.api.deps import PrincipalDep, RequestIdDep, get_session_service
from app.api.feature_gate import require_feature
from app.api.openapi import AUTHENTICATED, problem_responses
from app.api.params import DEFAULT_PAGE_SIZE, CursorQuery, LimitQuery, SessionIdPath
from app.schemas.messages import MessageCreate, MessagePage, MessageResponse
from app.services.session_service import SessionService

router = APIRouter(
    prefix="/v1/sessions/{session_id}/messages",
    tags=["sessions"],
    dependencies=[require_feature("sessions.api", default=True)],
)
SessionsDep = Annotated[SessionService, Depends(get_session_service)]
#: 404 covers "not the caller's session" and "the flag is off"; 422 the body.
MESSAGE_RESPONSES = problem_responses(*AUTHENTICATED, 404, 422, 503)


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    response_model=MessageResponse,
    operation_id="append_session_message",
    summary="Append a turn to one of my sessions",
    description=(
        "Appends a message to the caller's session and bumps the session's "
        "`updated_at`, audited as `session.append` with the session as target. "
        "`role` must be `user`, `assistant` or `system` and `content` 1-8 000 "
        "characters; anything else answers 422. A session owned by another "
        "subject answers 404 and is not modified. Spec 0004 AC-5."
    ),
    responses=MESSAGE_RESPONSES,
)
async def append_session_message(
    session_id: SessionIdPath,
    body: MessageCreate,
    principal: PrincipalDep,
    request_id: RequestIdDep,
    service: SessionsDep,
) -> MessageResponse:
    """Append one turn to the caller's session. Spec 0004 AC-5."""
    return await service.append_message(
        principal, session_id, message=body, request_id=request_id
    )


@router.get(
    "",
    response_model=MessagePage,
    operation_id="list_session_messages",
    summary="Read the conversation of one of my sessions",
    description=(
        "Returns the session's messages in conversation order — **oldest "
        "first, newest last** — paginated with `limit` (1-100, default 20) and "
        "the opaque `cursor` from the previous page. Audited as "
        "`session.read`. A session owned by another subject answers 404, so "
        "the conversation is never readable by anybody else. Spec 0004 AC-6."
    ),
    responses=MESSAGE_RESPONSES,
)
async def list_session_messages(
    session_id: SessionIdPath,
    principal: PrincipalDep,
    request_id: RequestIdDep,
    service: SessionsDep,
    limit: LimitQuery = DEFAULT_PAGE_SIZE,
    cursor: CursorQuery = None,
) -> MessagePage:
    """Return a page of the conversation, oldest first. Spec 0004 AC-6."""
    return await service.list_messages(
        principal, session_id, limit=limit, cursor=cursor, request_id=request_id
    )


__all__ = ["router"]
