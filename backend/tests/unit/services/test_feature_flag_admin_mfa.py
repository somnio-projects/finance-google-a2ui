from collections.abc import Sequence
from datetime import timedelta

import pytest

from app.core.errors import AuthorizationError
from app.core.principal import Principal
from app.helpers.clock import FixedClock
from app.models.audit_event import AuditEvent
from app.models.feature_flag import FeatureFlag
from app.services.audit_service import AuditService
from app.services.feature_flag_cache import FeatureFlagCache
from app.services.feature_flag_service import FeatureFlagService
from tests.conftest import FakeReporter


class _EmptyFlagRepository:
    async def list_all(self) -> Sequence[FeatureFlag]:
        return []


class _NullAuditRepository:
    async def add(self, entity: AuditEvent) -> AuditEvent:
        return entity


def _admin(*, amr: frozenset[str]) -> Principal:
    return Principal(
        subject="ops-admin",
        provider="jwt",
        scopes=frozenset({"admin"}),
        token_fingerprint="0123456789abcdef",  # gitleaks:allow
        auth_methods=amr,
    )


def _service(
    clock: FixedClock, reporter: FakeReporter, *, require_mfa: bool
) -> FeatureFlagService:
    return FeatureFlagService(
        repository=_EmptyFlagRepository(),  # type: ignore[arg-type]
        cache=FeatureFlagCache(ttl=timedelta(seconds=15), clock=clock),
        audit=AuditService(repository=_NullAuditRepository()),  # type: ignore[arg-type]
        reporter=reporter,
        force_disabled=[],
        require_mfa=require_mfa,
    )


async def test_admin_without_mfa_is_forbidden_when_mfa_required(
    clock: FixedClock, reporter: FakeReporter
) -> None:
    service = _service(clock, reporter, require_mfa=True)
    with pytest.raises(AuthorizationError, match="multi-factor"):
        await service.list_flags(_admin(amr=frozenset({"pwd"})), request_id="r")


@pytest.mark.parametrize(
    ("require_mfa", "amr"),
    [
        (True, frozenset({"pwd", "otp"})),
        (False, frozenset({"pwd"})),
        (False, frozenset()),
    ],
    ids=["required_and_present", "not_required_password_only", "not_required_absent"],
)
async def test_admin_passes_when_mfa_present_or_not_required(
    clock: FixedClock, reporter: FakeReporter, require_mfa: bool, amr: frozenset[str]
) -> None:
    service = _service(clock, reporter, require_mfa=require_mfa)
    assert await service.list_flags(_admin(amr=amr), request_id="r") == []


@pytest.mark.parametrize("operation", ["list", "set"], ids=["list", "set"])
async def test_admin_operations_require_admin_scope(
    clock: FixedClock, reporter: FakeReporter, operation: str
) -> None:
    service = _service(clock, reporter, require_mfa=False)
    user = _admin(amr=frozenset()).model_copy(update={"scopes": frozenset()})
    with pytest.raises(AuthorizationError, match="admin scope"):
        if operation == "list":
            await service.list_flags(user, request_id="r")
        else:
            await service.set_flag(
                user, key="x", enabled=True, description=None, request_id="r"
            )
