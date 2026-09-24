"""Admin controllers for feature flags (spec 0002) — scope ``admin`` required."""

from typing import Annotated

from fastapi import APIRouter, Depends, Path

from app.api.deps import PrincipalDep, RequestIdDep, get_feature_flag_service
from app.api.openapi import AUTHENTICATED, problem_responses
from app.schemas.feature_flags import (
    FLAG_KEY_PATTERN,
    FeatureFlagResponse,
    FeatureFlagUpdate,
)
from app.services.feature_flag_service import FeatureFlagService

router = APIRouter(prefix="/v1/admin/feature-flags", tags=["feature-flags"])
FlagsDep = Annotated[FeatureFlagService, Depends(get_feature_flag_service)]
FlagKey = Annotated[
    str,
    Path(
        min_length=3,
        max_length=100,
        pattern=FLAG_KEY_PATTERN,
        description="Flag key: lowercase dotted segments, `<domain>.<capability>`.",
        examples=["identity.audit"],
    ),
]
ADMIN_RESPONSES = problem_responses(*AUTHENTICATED, 403, 503)


@router.get(
    "",
    response_model=list[FeatureFlagResponse],
    operation_id="list_feature_flags",
    summary="List every persisted feature flag",
    description=(
        "Returns all persisted flags with the environment kill-switch applied, "
        "so the response is the state the gates actually enforce. Requires the "
        "`admin` scope (and an MFA `amr` claim in production); the read itself "
        "is audited as `feature_flag.list`. Spec 0002 AC-2."
    ),
    responses=ADMIN_RESPONSES,
)
async def list_feature_flags(
    principal: PrincipalDep, request_id: RequestIdDep, service: FlagsDep
) -> list[FeatureFlagResponse]:
    """Return every persisted flag (admin only, audited). Spec 0002 AC-2."""
    return await service.list_flags(principal, request_id=request_id)


@router.put(
    "/{key}",
    response_model=FeatureFlagResponse,
    operation_id="set_feature_flag",
    summary="Enable or disable a feature flag",
    description=(
        "Idempotent upsert of one flag: persists the state, refreshes the "
        "in-process cache so gates see it within the TTL, writes a "
        "`feature_flag.update` audit event with `target=<key>`, and emits the "
        "`feature_flag.toggled` metric. Requires the `admin` scope (and an MFA "
        "`amr` claim in production). A key listed in "
        "`FEATURE_FLAGS_FORCE_DISABLED` is persisted but still reported "
        "disabled — the kill-switch wins. Spec 0002 AC-1, AC-3, AC-4, AC-6."
    ),
    responses={**ADMIN_RESPONSES, **problem_responses(413, 422)},
)
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
