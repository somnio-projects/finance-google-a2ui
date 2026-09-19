from collections.abc import Sequence
from datetime import UTC, datetime, timedelta

from app.core.errors import DependencyUnavailableError
from app.core.principal import Principal
from app.helpers.clock import FixedClock
from app.models.audit_event import AuditEvent
from app.models.feature_flag import FeatureFlag
from app.services.audit_service import AuditService
from app.services.feature_flag_cache import FeatureFlagCache
from app.services.feature_flag_service import FeatureFlagService
from tests.conftest import FakeReporter


class FakeFlagRepository:
    def __init__(self, *, fail: bool = False) -> None:
        self.rows: dict[str, FeatureFlag] = {}
        self.reads = 0
        self.fail = fail

    async def get(self, key: str) -> FeatureFlag | None:
        self.reads += 1
        if self.fail:
            raise DependencyUnavailableError("database read failed")
        return self.rows.get(key)

    async def list_all(self) -> Sequence[FeatureFlag]:
        return [self.rows[k] for k in sorted(self.rows)]

    async def upsert(
        self, key: str, *, enabled: bool, description: str | None, updated_by: str
    ) -> FeatureFlag:
        flag = FeatureFlag(key=key, enabled=enabled, updated_by=updated_by)
        flag.description = description
        flag.updated_at = datetime.now(tz=UTC)
        self.rows[key] = flag
        return flag


class FakeAuditRepository:
    def __init__(self) -> None:
        self.events: list[AuditEvent] = []

    async def add(self, entity: AuditEvent) -> AuditEvent:
        self.events.append(entity)
        return entity


def build(
    clock: FixedClock,
    reporter: FakeReporter,
    *,
    repo: FakeFlagRepository | None = None,
    force_disabled: list[str] | None = None,
) -> tuple[FeatureFlagService, FakeFlagRepository, FakeAuditRepository]:
    repo = repo or FakeFlagRepository()
    audit_repo = FakeAuditRepository()
    service = FeatureFlagService(
        repository=repo,  # type: ignore[arg-type]
        cache=FeatureFlagCache(ttl=timedelta(seconds=15), clock=clock),
        audit=AuditService(repository=audit_repo),  # type: ignore[arg-type]
        reporter=reporter,
        force_disabled=force_disabled or [],
    )
    return service, repo, audit_repo


def admin(principal: Principal) -> Principal:
    return principal.model_copy(update={"scopes": frozenset({"admin"})})


async def test_is_enabled_uses_default_when_no_row_and_caches(
    clock: FixedClock, reporter: FakeReporter
) -> None:
    service, repo, _ = build(clock, reporter)
    assert await service.is_enabled("x.read") is True
    assert await service.is_enabled("x.read", default=False) is True  # cached
    assert repo.reads == 1
    clock.advance(timedelta(seconds=16))
    assert await service.is_enabled("x.read", default=False) is False
    assert repo.reads == 2


async def test_is_enabled_reads_row_value(
    clock: FixedClock, reporter: FakeReporter
) -> None:
    service, repo, _ = build(clock, reporter)
    await repo.upsert("x.read", enabled=False, description=None, updated_by="op")
    assert await service.is_enabled("x.read") is False


async def test_force_disabled_wins_over_everything(
    clock: FixedClock, reporter: FakeReporter, principal: Principal
) -> None:
    service, repo, audit_repo = build(clock, reporter, force_disabled=["x.read"])
    await repo.upsert("x.read", enabled=True, description=None, updated_by="op")
    assert await service.is_enabled("x.read") is False
    assert repo.reads == 0
    listed = await service.list_flags(admin(principal), request_id="r-list")
    assert [e.action for e in audit_repo.events] == ["feature_flag.list"]
    assert [(f.key, f.enabled) for f in listed] == [("x.read", False)]


async def test_read_failure_falls_back_to_default_and_reports(
    clock: FixedClock, reporter: FakeReporter
) -> None:
    service, _, _ = build(clock, reporter, repo=FakeFlagRepository(fail=True))
    assert await service.is_enabled("x.read", default=False) is False
    assert await service.is_enabled("x.read") is True
    assert len(reporter.exceptions) == 2


async def test_set_flag_persists_caches_audits_and_counts(
    clock: FixedClock, reporter: FakeReporter, principal: Principal
) -> None:
    service, repo, audit_repo = build(clock, reporter)
    response = await service.set_flag(
        admin(principal),
        key="x.read",
        enabled=False,
        description="off",
        request_id="r1",
    )
    assert response.enabled is False
    assert response.description == "off"
    assert response.updated_by == principal.subject
    assert repo.rows["x.read"].enabled is False
    assert await service.is_enabled("x.read") is False
    assert repo.reads == 0  # served by the cache the toggle refreshed
    assert [(e.action, e.target) for e in audit_repo.events] == [
        ("feature_flag.update", "x.read")
    ]
    assert audit_repo.events[0].request_id == "r1"
    assert (
        "feature_flag.toggled",
        {"key": "x.read", "enabled": "false"},
    ) in reporter.metrics
