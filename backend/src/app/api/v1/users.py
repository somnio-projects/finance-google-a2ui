"""Admin controllers for the provisioning registry (spec 0027) — ``admin`` scope."""

from typing import Annotated

from fastapi import APIRouter, Depends, Path, Query, Response, status

from app.api.deps import PrincipalDep, RequestIdDep, get_user_service
from app.api.openapi import AUTHENTICATED, problem_responses
from app.schemas.users import (
    EMAIL_PATTERN,
    UserInvite,
    UserResponse,
    UserStatusUpdate,
)
from app.services.user_service import UserService

router = APIRouter(prefix="/v1/admin/users", tags=["users"])
UsersDep = Annotated[UserService, Depends(get_user_service)]
EmailPath = Annotated[
    str,
    Path(
        min_length=6,
        max_length=320,
        pattern=EMAIL_PATTERN,
        description="The account's e-mail, lower-cased.",
        examples=["reviewer@google.com"],
    ),
]
LimitQuery = Annotated[
    int,
    Query(ge=1, le=200, description="How many accounts, newest first.", examples=[100]),
]
ADMIN_RESPONSES = problem_responses(*AUTHENTICATED, 403, 422, 503)


@router.get(
    "",
    response_model=list[UserResponse],
    operation_id="list_users",
    summary="List the provisioned accounts",
    description=(
        "Returns the provisioning registry, newest first. Requires the `admin` "
        "scope (and an MFA `amr` claim in production); audited as `user.list`. "
        "Spec 0027 AC-4."
    ),
    responses=ADMIN_RESPONSES,
)
async def list_users(
    principal: PrincipalDep,
    request_id: RequestIdDep,
    service: UsersDep,
    limit: LimitQuery = 100,
) -> list[UserResponse]:
    """Return the registry (admin only, audited). Spec 0027 AC-4."""
    return await service.list_users(principal, limit=limit, request_id=request_id)


@router.post(
    "",
    status_code=status.HTTP_201_CREATED,
    response_model=UserResponse,
    operation_id="invite_user",
    summary="Invite an account",
    description=(
        "Creates the account as `invited`, or moves an existing `requested` or "
        "`revoked` one back to `invited` — the same call approves a request and "
        "re-admits an offboarded person. Idempotent per e-mail. Requires the "
        "`admin` scope; audited as `user.invited` with `target=<email>`. Answers "
        "201 with a `Location` header. Spec 0027 AC-3."
    ),
    responses={**ADMIN_RESPONSES, **problem_responses(413)},
)
async def invite_user(
    body: UserInvite,
    principal: PrincipalDep,
    request_id: RequestIdDep,
    service: UsersDep,
    response: Response,
) -> UserResponse:
    """Invite ``body.email`` (admin only, audited). Spec 0027 AC-3."""
    created = await service.invite(principal, body, request_id=request_id)
    response.headers["Location"] = f"{router.prefix}/{created.email}"
    return created


@router.patch(
    "/{email}",
    response_model=UserResponse,
    operation_id="set_user_status",
    summary="Change an account's status",
    description=(
        "Moves an existing account to `invited`, `active`, `revoked` or "
        "`requested`. `revoked` is offboarding: the next `GET /v1/me/access` "
        "answers not provisioned, and the identity provider's token expiry is "
        "the only latency (ADR-B D-12). Requires the `admin` scope; audited as "
        "`user.<status>` with `target=<email>`. Spec 0027 AC-5."
    ),
    responses={**ADMIN_RESPONSES, **problem_responses(404, 413)},
)
async def set_user_status(
    email: EmailPath,
    body: UserStatusUpdate,
    principal: PrincipalDep,
    request_id: RequestIdDep,
    service: UsersDep,
) -> UserResponse:
    """Move ``email`` to ``body.status`` (admin only, audited). Spec 0027 AC-5."""
    return await service.set_status(
        principal, email=email.lower(), status=body.status, request_id=request_id
    )


__all__ = ["router"]
