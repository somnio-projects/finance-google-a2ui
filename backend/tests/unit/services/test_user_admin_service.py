"""``UserService`` — the administrative half (spec 0027 AC-3..AC-6)."""

import pytest

from app.core.errors import AuthorizationError, NotFoundError
from app.helpers.clock import FixedClock
from app.schemas.users import UserInvite
from app.services.audit_service import AuditService
from app.services.user_service import UserService
from tests.unit.services.user_doubles import (
    NOW,
    FakeAuditRepository,
    FakeUserRepository,
    admin,
    member,
)


def make(
    repo: FakeUserRepository, audit: FakeAuditRepository, *, require_mfa: bool = False
) -> UserService:
    return UserService(
        repository=repo,  # type: ignore[arg-type]
        audit=AuditService(repository=audit),  # type: ignore[arg-type]
        clock=FixedClock(NOW),
        require_mfa=require_mfa,
    )


async def test_listing_requires_admin_and_is_audited() -> None:
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    await repo.upsert(
        email="a@example.test",
        display_name=None,
        role="member",
        status="invited",
        invited_by="x",
    )
    service = make(repo, audit)
    with pytest.raises(AuthorizationError):
        await service.list_users(member(), limit=10, request_id="r1")
    rows = await service.list_users(admin(), limit=10, request_id="r2")
    assert [row.email for row in rows] == ["a@example.test"]
    assert [e.action for e in audit.events] == ["user.list"]


async def test_mfa_is_required_when_the_deployment_says_so() -> None:
    service = make(FakeUserRepository(), FakeAuditRepository(), require_mfa=True)
    with pytest.raises(AuthorizationError, match="second factor"):
        await service.list_users(admin(mfa=False), limit=1, request_id="r1")
    assert await service.list_users(admin(mfa=True), limit=1, request_id="r1") == []


async def test_invite_creates_or_readmits_and_names_the_inviter() -> None:
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    service = make(repo, audit)
    created = await service.invite(
        admin(),
        UserInvite(email="New@Example.test", display_name="New"),
        request_id="r1",
    )
    assert (created.email, created.status, created.invited_by) == (
        "new@example.test",
        "invited",
        "root@somnio.dev",
    )
    await repo.touch(repo.rows["new@example.test"], seen_at=NOW, status="revoked")
    again = await service.invite(
        admin(email=None), UserInvite(email="new@example.test"), request_id="r2"
    )
    assert (again.status, again.invited_by, again.display_name) == (
        "invited",
        "admin-1",
        "New",
    )
    assert [e.target for e in audit.events] == ["new@example.test", "new@example.test"]


async def test_set_status_moves_a_known_account_and_404s_an_unknown_one() -> None:
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    await repo.upsert(
        email="a@example.test",
        display_name=None,
        role="member",
        status="active",
        invited_by=None,
    )
    service = make(repo, audit)
    revoked = await service.set_status(
        admin(), email="a@example.test", status="revoked", request_id="r1"
    )
    assert revoked.status == "revoked"
    assert revoked.last_seen_at == NOW  # created_at stands in when never seen
    repo.rows["a@example.test"].last_seen_at = NOW.replace(hour=1)
    active = await service.set_status(
        admin(), email="a@example.test", status="active", request_id="r2"
    )
    assert active.last_seen_at == NOW.replace(hour=1)
    assert [e.action for e in audit.events] == ["user.revoked", "user.active"]
    with pytest.raises(NotFoundError):
        await service.set_status(
            admin(), email="zz@example.test", status="active", request_id="r3"
        )


async def test_request_access_records_once_and_never_downgrades() -> None:
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    service = make(repo, audit)
    await service.request_access("ask@example.test")
    assert repo.rows["ask@example.test"].status == "requested"
    await repo.touch(repo.rows["ask@example.test"], seen_at=NOW, status="active")
    await service.request_access("ask@example.test")
    assert repo.rows["ask@example.test"].status == "active"
