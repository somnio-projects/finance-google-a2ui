"""What open enrolment refuses, and the one case it changed its mind about.

Split from `test_self_enrolment.py` at the 150-line budget along the seam the
feature has: that file asserts who gets **in**, this one asserts who does not.

The ruling worth reading twice is `revoked` — everything else here follows
from the switch, and that one is the property the switch must not cost.
"""

from app.helpers.clock import FixedClock
from app.schemas.access import (
    ENROLLED_MESSAGE,
    NOT_PROVISIONED_MESSAGE,
)
from app.services.audit_service import AuditService
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


async def test_asking_for_access_does_not_make_things_worse() -> None:
    """`requested` is admitted, and this is a correction (spec 0042).

    Spec 0040 refused it, reasoning that a request waits on an admin. With
    enrolment **open** there is no admin to wait for, and the consequence was
    perverse: `POST /v1/access-requests` writes a `requested` row, so somebody
    who clicked *Request access* after being refused acquired the one status
    neither enrolment nor the provisioning job would move. Two people were
    stuck that way on dev before this.
    """
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    await repo.upsert(
        email=NEW,
        display_name=None,
        role="member",
        status="requested",
        invited_by=None,
    )

    access = await make(repo, audit, open_enrolment=True).access_for(
        member(NEW), request_id="r1"
    )
    row = await repo.find_by_email(NEW)

    assert access.provisioned is True
    assert access.message == ENROLLED_MESSAGE
    assert row is not None
    assert row.status == "active"
    assert [event.action for event in audit.events] == ["user.self_enrolled"]


async def test_a_request_still_waits_when_enrolment_is_closed() -> None:
    # The switch is what decides. With enrolment off, a request is still a
    # request and an admin still answers it.
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    await repo.upsert(
        email=NEW,
        display_name=None,
        role="member",
        status="requested",
        invited_by=None,
    )

    access = await make(repo, audit, open_enrolment=False).access_for(
        member(NEW), request_id="r1"
    )
    row = await repo.find_by_email(NEW)

    assert access.provisioned is False
    assert row is not None
    assert row.status == "requested"


async def test_a_revoked_account_is_never_readmitted_by_enrolment() -> None:
    # The case that matters most: an offboarding somebody performed. If
    # signing in again undid it, open enrolment would be a way back in for an
    # account that was deliberately closed.
    status = "revoked"
    repo, audit = FakeUserRepository(), FakeAuditRepository()
    await repo.upsert(
        email=NEW, display_name=None, role="member", status=status, invited_by="admin"
    )

    access = await make(repo, audit, open_enrolment=True).access_for(
        member(NEW), request_id="r1"
    )
    row = await repo.find_by_email(NEW)

    assert access.provisioned is False
    assert access.message == NOT_PROVISIONED_MESSAGE
    assert row is not None
    assert row.status == status
    assert audit.events == []


async def test_a_token_with_no_e_mail_claim_enrols_nothing() -> None:
    # A machine token has no verified e-mail, so there is nobody to enrol and
    # nothing to key a row on.
    repo, audit = FakeUserRepository(), FakeAuditRepository()

    access = await make(repo, audit, open_enrolment=True).access_for(
        member(None), request_id="r1"
    )

    assert access.provisioned is False
    assert await repo.find_by_email(None) is None  # type: ignore[arg-type]
    assert audit.events == []
