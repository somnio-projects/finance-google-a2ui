"""Access controllers (spec 0027): may this caller in, and how does one ask.

Two of the three routes are **unauthenticated by contract**, like the health
probes (ADR-B D-3): a person who cannot sign in yet has no bearer token to
present. Both are bounded — the request body is one e-mail, the answer never
says whether the e-mail is known, and the rate limit applies per client.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, Response, status

from app.api.deps import (
    PrincipalDep,
    RequestIdDep,
    UsersDep,
    get_preview_sign_in_service,
)
from app.api.openapi import AUTHENTICATED, problem_responses
from app.schemas.access import (
    AccessRequest,
    AccessResponse,
    PreviewSignIn,
    PreviewSignInResponse,
)
from app.services.preview_sign_in_service import PreviewSignInService

router = APIRouter(prefix="/v1", tags=["identity"])
PreviewDep = Annotated[PreviewSignInService, Depends(get_preview_sign_in_service)]


@router.get(
    "/me/access",
    response_model=AccessResponse,
    operation_id="read_my_access",
    summary="Say whether the caller may use the preview",
    description=(
        "Looks the verified token's `email` up in the provisioning registry. "
        "An `invited` account becomes `active` on its first call (audited as "
        "`user.activated`); a missing, `requested` or `revoked` one answers "
        "`provisioned: false` with the sentence the client shows verbatim. "
        "Always 200 for a valid token: the decision is data, not an error. "
        "Spec 0027 AC-1."
    ),
    responses=problem_responses(*AUTHENTICATED, 503),
)
async def read_my_access(
    principal: PrincipalDep, request_id: RequestIdDep, service: UsersDep
) -> AccessResponse:
    """Return the caller's provisioning state. Spec 0027 AC-1."""
    return await service.access_for(principal, request_id=request_id)


@router.post(
    "/access-requests",
    status_code=status.HTTP_202_ACCEPTED,
    response_class=Response,
    operation_id="request_access",
    summary="Ask to be invited",
    description=(
        "Records the e-mail as `requested` for an admin to approve. "
        "Unauthenticated by contract — the caller has no token yet — and "
        "answers 202 with no body whether or not the e-mail is already known, "
        "so it cannot be used to enumerate accounts. Spec 0027 AC-6."
    ),
    responses=problem_responses(422, 429, 500, 503),
)
async def request_access(body: AccessRequest, service: UsersDep) -> Response:
    """Record an access request; never reveals whether it is new. Spec 0027 AC-6."""
    await service.request_access(body.email)
    return Response(status_code=status.HTTP_202_ACCEPTED)


@router.post(
    "/preview-sign-ins",
    status_code=status.HTTP_201_CREATED,
    response_model=PreviewSignInResponse,
    operation_id="create_preview_sign_in",
    summary="Sign in with a provisioned e-mail (local stacks only)",
    description=(
        "Exchanges a provisioned e-mail for a development bearer token. Exists "
        "only while `AUTH_PROVIDER=jwt` and `AUTH_PREVIEW_SIGN_IN_ENABLED=true` "
        "— every deployed environment runs `oidc` and answers 404 "
        "`feature-disabled`. An unknown or revoked e-mail answers 403 "
        "`not-provisioned`. Audited as `user.preview_sign_in`. Spec 0027 OD-3."
    ),
    responses=problem_responses(403, 404, 422, 429, 500, 503),
)
async def create_preview_sign_in(
    body: PreviewSignIn, request_id: RequestIdDep, service: PreviewDep
) -> PreviewSignInResponse:
    """Mint a local token for a provisioned e-mail. Spec 0027 OD-3."""
    return await service.sign_in(body.email, request_id=request_id)


__all__ = ["router"]
