"""``UserService`` — the provisioning decisions (spec 0027 AC-1..AC-6)."""

import pytest

from app.domain.persona import PortfolioOwner
from app.helpers.clock import FixedClock
from app.schemas.access import NOT_PROVISIONED_MESSAGE, WELCOME_MESSAGE
from app.services.audit_service import AuditService
from app.services.user_service import UserService
from tests.unit.services.user_doubles import (
    NOW,
    FakeAuditRepository,
    FakeUserRepository,
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


@pytest.mark.parametrize(
    ("email", "status"),
    [
        (None, None),
        ("nobody@example.test", None),
        ("asked@example.test", "requested"),
        ("gone@example.test", "revoked"),
    ],
    ids=["no-email-claim", "unknown", "requested", "revoked"],
)
async def test_access_is_denied_unless_invited_or_active(
    email: str | None, status: str | None
) -> None:
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    if email and status:
        await repo.upsert(
            email=email,
            display_name=None,
            role="member",
            status=status,
            invited_by=None,
        )
    access = await make(repo, audit).access_for(member(email), request_id="r1")
    assert access.provisioned is False
    assert access.status == status
    assert access.message == NOT_PROVISIONED_MESSAGE
    assert audit.events == []


async def test_first_access_activates_an_invitee_and_audits_it() -> None:
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    await repo.upsert(
        email="person@example.test",
        display_name="Alex",
        role="member",
        status="invited",
        invited_by="root@somnio.dev",
    )
    access = await make(repo, audit).access_for(
        member("Person@Example.test"), request_id="r1"
    )
    assert access.provisioned is True
    assert (access.status, access.role, access.display_name) == (
        "active",
        "member",
        "Alex",
    )
    assert access.message == WELCOME_MESSAGE
    assert repo.rows["person@example.test"].last_seen_at == NOW
    assert [(e.action, e.target) for e in audit.events] == [
        ("user.activated", "person@example.test")
    ]


async def test_a_later_access_only_touches_the_row() -> None:
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    await repo.upsert(
        email="person@example.test",
        display_name=None,
        role="admin",
        status="active",
        invited_by=None,
    )
    access = await make(repo, audit).access_for(member(), request_id="r1")
    assert (access.provisioned, access.status, access.role) == (True, "active", "admin")
    assert audit.events == []


async def test_owner_for_prefers_the_registry_name_then_the_e_mail() -> None:
    """Spec 0030 — the shell greets the person the registry knows."""
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    await repo.upsert(
        email="person@example.test",
        display_name="Priya Natarajan",
        role="member",
        status="active",
        invited_by=None,
    )
    service = make(repo, audit)

    named = await service.owner_for(member("person@example.test"))
    by_email = await service.owner_for(member("stranger@example.test"))
    anonymous = await service.owner_for(member(None))

    assert named == PortfolioOwner(name="Priya Natarajan", initial="P")
    assert by_email == PortfolioOwner(name="Stranger", initial="S")
    assert anonymous is None
