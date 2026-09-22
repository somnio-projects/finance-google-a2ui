"""``require_feature`` — the dependency that turns a route on or off (spec 0002).

Usage::

    @router.get("/thing", dependencies=[require_feature("things.read")])
    async def read_thing(...): ...

A disabled flag answers 404 ``feature-disabled`` before the route body (and
before its own auth dependency) runs, so a switched-off endpoint neither
executes nor advertises itself.

The gate is an object rather than a closure so that a route can be *read* as
well as run: ``api.route_facts`` walks each route's dependency tree and
reports which flag guards it, and a closure keeps its key where nothing can
see it (spec 0035 OD-3).
"""

from typing import Annotated

from fastapi import Depends, params

from app.api.deps import get_feature_flag_service
from app.core.errors import FeatureDisabledError
from app.services.feature_flag_service import FeatureFlagService


class FeatureGate:
    """A callable dependency that rejects requests while ``key`` is off."""

    __slots__ = ("default", "key")

    def __init__(self, key: str, *, default: bool) -> None:
        """Remember the flag and the state assumed when no row exists."""
        self.key = key
        self.default = default

    async def __call__(
        self,
        service: Annotated[FeatureFlagService, Depends(get_feature_flag_service)],
    ) -> None:
        """Reject the request when the flag resolves to disabled."""
        if not await service.is_enabled(self.key, default=self.default):
            raise FeatureDisabledError(f"feature {self.key!r} is disabled")


def require_feature(key: str, *, default: bool = True) -> params.Depends:
    """Build a dependency that rejects requests while ``key`` is off (0002 AC-1).

    Args:
        key: Flag key, e.g. ``identity.audit``.
        default: State assumed when no row exists and no kill-switch applies.
    """
    return Depends(FeatureGate(key, default=default))


__all__ = ["FeatureGate", "require_feature"]
