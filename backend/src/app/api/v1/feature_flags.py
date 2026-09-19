"""Admin controllers for feature flags (spec 0002) — scope ``admin`` required."""

from typing import Annotated

from fastapi import APIRouter, Depends, Path

from app.api.deps import PrincipalDep, RequestIdDep, get_feature_flag_service
from app.schemas.feature_flags import (
    FLAG_KEY_PATTERN,
    FeatureFlagResponse,
    FeatureFlagUpdate,
)
from app.services.feature_flag_service import FeatureFlagService

router = APIRouter(prefix="/v1/admin/feature-flags", tags=["feature-flags"])
FlagsDep = Annotated[FeatureFlagService, Depends(get_feature_flag_service)]
FlagKey = Annotated[str, Path(min_length=3, max_length=100, pattern=FLAG_KEY_PATTERN)]


@router.get("", response_model=list[FeatureFlagResponse], summary="List flags")
async def list_feature_flags(
    principal: PrincipalDep, request_id: RequestIdDep, service: FlagsDep
) -> list[FeatureFlagResponse]:
    """Return every persisted flag (admin only, audited). Spec 0002 AC-2."""
    return await service.list_flags(principal, request_id=request_id)


@router.put("/{key}", response_model=FeatureFlagResponse, summary="Set a flag")
async def set_feature_flag(
    key: FlagKey,
    body: FeatureFlagUpdate,
    principal: PrincipalDep,
    request_id: RequestIdDep,
    service: FlagsDep,
) -> FeatureFlagResponse:
    """Enable or disable ``key`` at runtime (admin, audited). Spec 0002 AC-1/3/6."""
    return await service.set_flag(
        principal,
        key=key,
        enabled=body.enabled,
        description=body.description,
        request_id=request_id,
    )


__all__ = ["router"]
