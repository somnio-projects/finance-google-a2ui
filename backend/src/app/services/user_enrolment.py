"""Admitting a verified identity the registry has never seen (spec 0040).

Its own module, not a method on ``UserService``: that class was at the
150-line budget, and this is a **use case** — one decision, one write, one
audit event — rather than another way of reading the registry.

Synchronous, and measured. On the seeded local stack a brand-new identity's
first read — which also seeds sixteen lots and forty-eight transactions —
answers in **105 ms**, and the second in 7 ms. There is no work here worth a
queue; a background job would replace a hundred milliseconds nobody notices
with a wait somebody has to be told about.
"""

from typing import Final

from app.core.principal import Principal
from app.models.user import User
from app.repositories.user_repository import UserRepository
from app.schemas.access import ENROLLED_MESSAGE, AccessResponse
from app.services.audit_service import AuditService

#: What the registry records as the inviter, so an audit reader can tell a
#: self-enrolled account from one an admin invited.
SELF_ENROLMENT: Final[str] = "self-enrolment"

#: The statuses open enrolment may admit. `None` is nobody the registry has
#: seen. `requested` is somebody who ASKED — and with enrolment open there is
#: no admin left to wait for, so leaving them refused made *asking* the worse
#: move (spec 0042). **`revoked` is absent and must stay absent**: an
#: offboarding somebody performed is not undone by signing in again.
ENROLLABLE: Final[frozenset[str | None]] = frozenset({None, "requested"})


def enrollable(row: User | None) -> bool:
    """Whether open enrolment may admit the registry's answer for this caller."""
    return (row.status if row else None) in ENROLLABLE


async def enrol(
    repository: UserRepository,
    audit: AuditService,
    principal: Principal,
    email: str,
    *,
    request_id: str,
) -> AccessResponse:
    """Admit a verified identity the registry has never seen (spec 0040).

    **Only when there is no row at all.** A ``revoked`` account is an
    offboarding somebody performed, and signing in again must not undo
    it; a ``requested`` one is waiting for a decision that is still an
    admin's. Both keep the answer they already had.

    A `member`, never an `admin`: the first admins come from
    ``AUTH_BOOTSTRAP_ADMINS`` and nothing else creates one (spec 0027
    OD-2).
    """
    row = await repository.upsert(
        email=email,
        display_name=None,
        role="member",
        status="active",
        invited_by=SELF_ENROLMENT,
    )
    await audit.record(
        principal,
        action="user.self_enrolled",
        request_id=request_id,
        target=email,
    )
    return AccessResponse(
        email=row.email,
        provisioned=True,
        status=row.status,  # pyright: ignore[reportArgumentType]
        role=row.role,  # pyright: ignore[reportArgumentType]
        display_name=row.display_name,
        message=ENROLLED_MESSAGE,
    )


__all__ = ["ENROLLABLE", "SELF_ENROLMENT", "enrol", "enrollable"]
