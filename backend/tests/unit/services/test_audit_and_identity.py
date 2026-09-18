from collections.abc import Sequence
from datetime import UTC, datetime

from app.core.principal import Principal
from app.models.audit_event import AuditEvent
from app.services.audit_service import MAX_HISTORY, AuditService
from app.services.identity_service import IdentityService


class FakeAuditRepository:
    """In-memory stand-in for ``AuditRepository``."""

    def __init__(self) -> None:
        self.events: list[AuditEvent] = []
        self.requested_limits: list[int] = []

    async def add(self, entity: AuditEvent) -> AuditEvent:
        entity.created_at = datetime.now(tz=UTC)
        self.events.append(entity)
        return entity

    async def list_for_subject(
        self, subject: str, *, limit: int
    ) -> Sequence[AuditEvent]:
        self.requested_limits.append(limit)
        return [e for e in self.events if e.subject == subject][:limit]


async def test_record_persists_principal_action_and_fingerprint(
    principal: Principal,
) -> None:
    repo = FakeAuditRepository()
    event = await AuditService(repo).record(  # type: ignore[arg-type]
        principal, action="identity.read", request_id="req-1"
    )
    assert event.subject == principal.subject
    assert event.provider == principal.provider
    assert event.action == "identity.read"
    assert event.token_fingerprint == principal.token_fingerprint
    assert event.request_id == "req-1"
    assert repo.events == [event]


async def test_history_maps_rows_to_responses_and_clamps_limit(
    principal: Principal,
) -> None:
    repo = FakeAuditRepository()
    service = AuditService(repo)  # type: ignore[arg-type]
    await service.record(principal, action="a", request_id="r")
    history = await service.history(principal, limit=10_000)
    assert repo.requested_limits == [MAX_HISTORY]
    assert [h.action for h in history] == ["a"]
    assert history[0].request_id == "r"
    await service.history(principal, limit=0)
    assert repo.requested_limits[-1] == 1


async def test_identity_describe_audits_then_returns_sorted_scopes(
    principal: Principal,
) -> None:
    repo = FakeAuditRepository()
    principal = principal.model_copy(update={"scopes": frozenset({"z", "a"})})
    service = IdentityService(AuditService(repo))  # type: ignore[arg-type]
    me = await service.describe(principal, request_id="req-9")
    assert me.subject == principal.subject
    assert me.scopes == ["a", "z"]
    assert me.email == principal.email
    assert [e.action for e in repo.events] == ["identity.read"]
    assert repo.events[0].request_id == "req-9"
