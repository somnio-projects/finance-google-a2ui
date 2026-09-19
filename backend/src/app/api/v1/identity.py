"""Identity controllers — every route requires a verified bearer token."""

from typing import Annotated

from fastapi import APIRouter, Depends, Query

from app.api.deps import (
    PrincipalDep,
    RequestIdDep,
    get_audit_service,
    get_identity_service,
)
from app.api.feature_gate import require_feature
from app.api.openapi import AUTHENTICATED, problem_responses
from app.schemas.identity import AuditEventResponse, MeResponse
from app.services.audit_service import AuditService
from app.services.identity_service import IdentityService

router = APIRouter(prefix="/v1", tags=["identity"])


@router.get(
    "/me",
    response_model=MeResponse,
    operation_id="read_current_identity",
    summary="Describe the authenticated caller",
    description=(
        "Returns the identity behind the bearer token — subject, provider, "
        "e-mail when the provider supplies one, and the granted scopes — and "
        "records an `identity.read` audit event. Spec 0001 AC-4."
    ),
    responses=problem_responses(*AUTHENTICATED, 503),
)
async def read_me(
    principal: PrincipalDep,
    request_id: RequestIdDep,
    service: Annotated[IdentityService, Depends(get_identity_service)],
) -> MeResponse:
    """Describe the authenticated caller and record the access."""
    return await service.describe(principal, request_id=request_id)


@router.get(
    "/me/audit-events",
    response_model=list[AuditEventResponse],
    operation_id="list_my_audit_events",
    summary="List my recent audit events",
    description=(
        "Returns the caller's own audit events, newest first, capped at 100 "
        "(`AuditService.MAX_HISTORY`). Never returns another subject's rows. "
        "Gated by the `identity.audit` feature flag: while it is off the route "
        "answers 404 `feature-disabled`. Spec 0001 AC-5, spec 0002 AC-1."
    ),
    responses=problem_responses(*AUTHENTICATED, 404, 422, 503),
    dependencies=[require_feature("identity.audit")],
)
async def read_my_audit(
    principal: PrincipalDep,
    service: Annotated[AuditService, Depends(get_audit_service)],
    limit: Annotated[
        int,
        Query(
            ge=1,
            le=100,
            description="How many events to return, newest first.",
            examples=[20],
        ),
    ] = 20,
) -> list[AuditEventResponse]:
    """Return the caller's newest audit events."""
    return await service.history(principal, limit=limit)


__all__ = ["router"]
