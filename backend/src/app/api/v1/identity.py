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
from app.schemas.identity import AuditEventResponse, MeResponse
from app.services.audit_service import AuditService
from app.services.identity_service import IdentityService

router = APIRouter(prefix="/v1", tags=["identity"])


@router.get("/me", response_model=MeResponse, summary="Who am I")
async def read_me(
    principal: PrincipalDep,
    request_id: RequestIdDep,
    service: Annotated[IdentityService, Depends(get_identity_service)],
) -> MeResponse:
    """Describe the authenticated caller and record the access."""
    return await service.describe(principal, request_id=request_id)


@router.get(
    "/me/audit",
    response_model=list[AuditEventResponse],
    summary="My recent audit events",
    dependencies=[require_feature("identity.audit")],
)
async def read_my_audit(
    principal: PrincipalDep,
    service: Annotated[AuditService, Depends(get_audit_service)],
    limit: Annotated[int, Query(ge=1, le=100)] = 20,
) -> list[AuditEventResponse]:
    """Return the caller's newest audit events."""
    return await service.history(principal, limit=limit)


__all__ = ["router"]
