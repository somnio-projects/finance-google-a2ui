"""``require_feature`` — the dependency that turns a route on or off (spec 0002).

Usage::

    @router.get("/thing", dependencies=[require_feature("things.read")])
    async def read_thing(...): ...

A disabled flag answers 404 ``feature-disabled`` before the route body (and
before its own auth dependency) runs, so a switched-off endpoint neither
executes nor advertises itself.
"""

from typing import Annotated

from fastapi import Depends, params

from app.api.deps import get_feature_flag_service
from app.core.errors import FeatureDisabledError
from app.services.feature_flag_service import FeatureFlagService


def require_feature(key: str, *, default: bool = True) -> params.Depends:
    """Build a FastAPI dependency that rejects requests while ``key`` is off.

    Args:
        key: Flag key, e.g. ``identity.audit``.
        default: State assumed when no row exists and no kill-switch applies.
    """

    async def _gate(
        service: Annotated[FeatureFlagService, Depends(get_feature_flag_service)],
    ) -> None:
        if not await service.is_enabled(key, default=default):
            raise FeatureDisabledError(f"feature {key!r} is disabled")

    return Depends(_gate)


__all__ = ["require_feature"]
