"""Conversation-session controllers (spec 0004, GGU-46).

Every route answers for the subject of the bearer token and for nobody else:
the owner is never a parameter, and a session owned by another subject is
indistinguishable from one that does not exist.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import PrincipalDep, RequestIdDep, get_session_service
from app.api.feature_gate import require_feature
from app.api.openapi import AUTHENTICATED, problem_responses
from app.api.params import DEFAULT_PAGE_SIZE, CursorQuery, LimitQuery, SessionIdPath
from app.schemas.sessions import SessionCreate, SessionPage, SessionResponse
from app.services.session_service import SessionService

router = APIRouter(
    prefix="/v1/sessions",
    tags=["sessions"],
    dependencies=[require_feature("sessions.api", default=True)],
)
SessionsDep = Annotated[SessionService, Depends(get_session_service)]
#: 404 covers both "no such session" and "the flag is off"; 422 the parameters.
SESSION_RESPONSES = problem_responses(*AUTHENTICATED, 404, 422, 503)


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    response_model=SessionResponse,
    operation_id="create_session",
    summary="Open a conversation session",
    description=(
        "Opens a session owned by the verified subject of the bearer token and "
        "answers 201 with a `Location` header pointing at it. The owner comes "
        "from the token, never from the body — there is no field for it. The "
        "creation is audited as `session.create`. Spec 0004 AC-1."
    ),
    responses=SESSION_RESPONSES,
)
async def create_session(
    body: SessionCreate,
    principal: PrincipalDep,
    request_id: RequestIdDep,
    service: SessionsDep,
    response: Response,
) -> SessionResponse:
    """Open a session owned by the caller. Spec 0004 AC-1."""
    created = await service.create(principal, title=body.title, request_id=request_id)
    response.headers["Location"] = f"{router.prefix}/{created.id}"
    return created


@router.get(
    "",
    response_model=SessionPage,
    operation_id="list_sessions",
    summary="List my conversation sessions",
    description=(
        "Returns the caller's own sessions, newest first, never anybody "
        "else's. Paginate with `limit` (1-100, default 20) and the opaque "
        "`cursor` from the previous page's `next_cursor`; the last page "
        "carries `next_cursor: null`. Audited as `session.list`. Spec 0004 AC-2."
    ),
    responses=SESSION_RESPONSES,
)
async def list_sessions(
    principal: PrincipalDep,
    request_id: RequestIdDep,
    service: SessionsDep,
    limit: LimitQuery = DEFAULT_PAGE_SIZE,
    cursor: CursorQuery = None,
) -> SessionPage:
    """Return a page of the caller's sessions. Spec 0004 AC-2."""
    return await service.list_sessions(
        principal, limit=limit, cursor=cursor, request_id=request_id
    )


@router.get(
    "/{session_id}",
    response_model=SessionResponse,
    operation_id="read_session",
    summary="Read one of my sessions",
    description=(
        "Returns the session when the caller owns it and audits a "
        "`session.read`. A session owned by another subject answers **404 "
        "`not-found`**, indistinguishable from the answer for an id that never "
        "existed: a 403 would confirm it exists (ADR-A D-2). Spec 0004 AC-3."
    ),
    responses=SESSION_RESPONSES,
)
async def read_session(
    session_id: SessionIdPath,
    principal: PrincipalDep,
    request_id: RequestIdDep,
    service: SessionsDep,
) -> SessionResponse:
    """Return the caller's own session, or 404. Spec 0004 AC-3."""
    return await service.get(principal, session_id, request_id=request_id)


@router.delete(
    "/{session_id}",
    status_code=status.HTTP_204_NO_CONTENT,
    operation_id="delete_session",
    summary="Delete one of my sessions",
    description=(
        "Deletes the caller's session and every message in it (the database "
        "cascades) and answers 204 with no body, audited as `session.delete`. "
        "Repeating the call answers 404 and changes nothing further — the "
        "effect on the server is idempotent. Another subject's session answers "
        "404 and is left untouched. Spec 0004 AC-4."
    ),
    responses=SESSION_RESPONSES,
)
async def delete_session(
    session_id: SessionIdPath,
    principal: PrincipalDep,
    request_id: RequestIdDep,
    service: SessionsDep,
) -> None:
    """Delete the caller's own session. Spec 0004 AC-4."""
    await service.delete(principal, session_id, request_id=request_id)


__all__ = ["router"]
