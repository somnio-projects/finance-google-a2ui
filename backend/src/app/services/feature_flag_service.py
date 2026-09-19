"""Feature-flag use cases (spec 0002).

Resolution order for ``is_enabled``: env kill-switch → cache → database →
the caller's default. Toggling requires the ``admin`` scope and is audited.
"""

from collections.abc import Collection
from typing import Final

import structlog

from app.core.dto import from_row
from app.core.errors import AppError, AuthorizationError
from app.core.logging import get_logger
from app.core.principal import Principal
from app.core.protocols import ErrorReporter
from app.models.feature_flag import FeatureFlag
from app.repositories.feature_flag_repository import FeatureFlagRepository
from app.schemas.feature_flags import FeatureFlagResponse
from app.services.audit_service import AuditService
from app.services.feature_flag_cache import FeatureFlagCache

ADMIN_SCOPE: Final[str] = "admin"
# design: the resolver logs its own fallbacks; a module logger keeps the constructor
# focused on collaborators that affect behaviour (the reporter is injected).
log: structlog.stdlib.BoundLogger = get_logger(__name__)


class FeatureFlagService:
    """Read flags cheaply, change them safely."""

    def __init__(
        self,
        *,
        repository: FeatureFlagRepository,
        cache: FeatureFlagCache,
        audit: AuditService,
        reporter: ErrorReporter,
        force_disabled: Collection[str],
        require_mfa: bool = False,
    ) -> None:
        """Inject collaborators; the last two arguments come from settings."""
        self._require_mfa = require_mfa
        self._repository = repository
        self._cache = cache
        self._audit = audit
        self._reporter = reporter
        self._force_disabled = frozenset(force_disabled)

    async def is_enabled(self, key: str, *, default: bool = True) -> bool:
        """Return the effective state of ``key``; never raises (AC-4, AC-5)."""
        if key in self._force_disabled:
            return False
        cached = self._cache.get(key)
        if cached is not None:
            return cached
        try:
            flag = await self._repository.get(key)
        except AppError as exc:
            self._reporter.capture_exception(exc)
            log.warning("feature_flag_read_failed", key=key, fallback=default)
            return default
        value = default if flag is None else flag.enabled
        self._cache.put(key, value)
        return value

    async def list_flags(
        self, principal: Principal, *, request_id: str
    ) -> list[FeatureFlagResponse]:
        """Return every flag with the kill-switch applied (AC-2; audited)."""
        self._require_admin(principal)
        flags = await self._repository.list_all()
        await self._audit.record(
            principal, action="feature_flag.list", request_id=request_id
        )
        return [self._to_response(flag) for flag in flags]

    async def set_flag(
        self,
        principal: Principal,
        *,
        key: str,
        enabled: bool,
        description: str | None,
        request_id: str,
    ) -> FeatureFlagResponse:
        """Persist, refresh the cache and audit the change (spec 0002 AC-1, AC-3)."""
        self._require_admin(principal)
        flag = await self._repository.upsert(
            key, enabled=enabled, description=description, updated_by=principal.subject
        )
        self._cache.put(key, flag.enabled)
        await self._audit.record(
            principal, action="feature_flag.update", target=key, request_id=request_id
        )
        self._reporter.increment(
            "feature_flag.toggled", tags={"key": key, "enabled": str(enabled).lower()}
        )
        return self._to_response(flag)

    def _require_admin(self, principal: Principal) -> None:
        if not principal.has_scope(ADMIN_SCOPE):
            raise AuthorizationError("feature flags require the admin scope")
        if self._require_mfa and not principal.is_mfa:
            raise AuthorizationError("admin operations require a multi-factor session")

    def _to_response(self, flag: FeatureFlag) -> FeatureFlagResponse:
        response = from_row(FeatureFlagResponse, flag)
        if response.key in self._force_disabled:
            return response.model_copy(update={"enabled": False})
        return response


__all__ = ["ADMIN_SCOPE", "FeatureFlagService"]
