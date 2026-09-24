"""Open enrolment — a verified identity the registry has never seen (spec 0040).

The TL's instruction was *"necesito que pueda loguear con SSO libremente, no
vamos a tener restricciones aún"*, and then *"el aprovisionamiento debería
hacerse de manera automática"*. So the registry is not bypassed — it fills
itself in, which keeps the audit trail and keeps every later decision reading
one table.

The cases that matter are the ones it must **refuse** to enrol: an offboarded
account must not be readmitted by signing in again, and the switch must be off
unless a deployment asks for it.
"""

from app.helpers.clock import FixedClock
from app.schemas.access import (
    ENROLLED_MESSAGE,
    NOT_PROVISIONED_MESSAGE,
    WELCOME_MESSAGE,
)
from app.services.audit_service import AuditService
from app.services.user_enrolment import SELF_ENROLMENT
from app.services.user_service import UserService
from tests.unit.services.user_doubles import (
    NOW,
    FakeAuditRepository,
    FakeUserRepository,
    member,
)

NEW = "stranger@example.test"


def make(
    repo: FakeUserRepository,
    audit: FakeAuditRepository,
    *,
    open_enrolment: bool,
) -> UserService:
    return UserService(
        repository=repo,  # type: ignore[arg-type]
        audit=AuditService(repository=audit),  # type: ignore[arg-type]
        clock=FixedClock(NOW),
        open_enrolment=open_enrolment,
    )


async def test_the_switch_is_what_decides_and_it_is_off_by_default() -> None:
    # The same caller, the same empty registry, two deployments.
    repo, audit = FakeUserRepository(), FakeAuditRepository()

    closed = await make(repo, audit, open_enrolment=False).access_for(
        member(NEW), request_id="r1"
    )

    assert closed.provisioned is False
    assert closed.message == NOT_PROVISIONED_MESSAGE
    assert audit.events == []


async def test_an_unknown_identity_enrols_itself_as_an_active_member() -> None:
    repo, audit = FakeUserRepository(), FakeAuditRepository()

    access = await make(repo, audit, open_enrolment=True).access_for(
        member(NEW), request_id="r1"
    )

    assert access.provisioned is True
    assert access.status == "active"
    # Never an admin: the first admins come from AUTH_BOOTSTRAP_ADMINS and
    # nothing else creates one (spec 0027 OD-2).
    assert access.role == "member"
    assert access.message == ENROLLED_MESSAGE


async def test_the_enrolment_is_recorded_in_the_registry_and_the_audit() -> None:
    repo, audit = FakeUserRepository(), FakeAuditRepository()

    await make(repo, audit, open_enrolment=True).access_for(
        member(NEW), request_id="r1"
    )
    row = await repo.find_by_email(NEW)

    assert row is not None
    # `invited_by` is how an audit reader tells this from an admin's invite.
    assert row.invited_by == SELF_ENROLMENT
    assert [event.action for event in audit.events] == ["user.self_enrolled"]
    assert audit.events[0].target == NEW


async def test_the_second_sign_in_is_a_welcome_back_not_a_second_enrolment() -> None:
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    service = make(repo, audit, open_enrolment=True)

    await service.access_for(member(NEW), request_id="r1")
    again = await service.access_for(member(NEW), request_id="r2")

    assert again.message == WELCOME_MESSAGE
    assert [event.action for event in audit.events] == ["user.self_enrolled"]
