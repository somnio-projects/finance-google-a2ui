"""Provisioning use cases (spec 0027): who may use the preview, and who says so.

An identity provider proves *who* the caller is; this service decides whether
that person was invited. Every administrative action is audited under
``user.*`` with the e-mail as ``target``, and the ``admin`` scope (plus MFA
where the deployment requires it) is checked here, not in the controller.
"""

from datetime import datetime
from typing import Final

from app.core.errors import AuthorizationError, NotFoundError
from app.core.principal import Principal
from app.core.protocols import Clock
from app.domain.persona import PortfolioOwner, owner_from
from app.repositories.user_repository import UserRepository
from app.schemas.access import (
    NOT_PROVISIONED_MESSAGE,
    PROVISIONED,
    WELCOME_MESSAGE,
    AccessResponse,
)
from app.schemas.users import UserInvite, UserResponse
from app.services.audit_service import AuditService
from app.services.user_enrolment import enrol, enrollable

ADMIN_SCOPE: Final[str] = "admin"


class UserService:
    """Read and change the provisioning registry."""

    def __init__(
        self,
        *,
        repository: UserRepository,
        audit: AuditService,
        clock: Clock,
        require_mfa: bool = False,
        open_enrolment: bool = False,
    ) -> None:
        """Bind the request-scoped repository, the audit trail and the clock."""
        self._repository = repository
        self._audit = audit
        self._clock = clock
        self._require_mfa = require_mfa
        self._open_enrolment = open_enrolment

    async def access_for(
        self, principal: Principal, *, request_id: str
    ) -> AccessResponse:
        """Say whether ``principal`` may use the preview; activate an invitee."""
        email = principal.email.lower() if principal.email else None
        row = await self._repository.find_by_email(email) if email else None
        if email and self._open_enrolment and enrollable(row):
            return await enrol(
                self._repository, self._audit, principal, email, request_id=request_id
            )
        if row is None or row.status not in PROVISIONED:
            return AccessResponse(
                email=email,
                provisioned=False,
                status=row.status if row else None,  # pyright: ignore[reportArgumentType]
                message=NOT_PROVISIONED_MESSAGE,
            )
        now: datetime = self._clock.now()
        if row.status == "invited":
            row = await self._repository.touch(row, seen_at=now, status="active")
            await self._audit.record(
                principal, action="user.activated", request_id=request_id, target=email
            )
        else:
            row = await self._repository.touch(row, seen_at=now)
        return AccessResponse(
            email=row.email,
            provisioned=True,
            status=row.status,  # pyright: ignore[reportArgumentType]
            role=row.role,  # pyright: ignore[reportArgumentType]
            display_name=row.display_name,
            message=WELCOME_MESSAGE,
        )

    async def owner_for(self, principal: Principal) -> PortfolioOwner | None:
        """Name ``principal`` for the shell (spec 0030): registry first, e-mail next."""
        email = principal.email.lower() if principal.email else None
        row = await self._repository.find_by_email(email) if email else None
        return owner_from(display_name=row.display_name if row else None, email=email)

    async def list_users(
        self, principal: Principal, *, limit: int, request_id: str
    ) -> list[UserResponse]:
        """Return the registry, newest first (admin only, audited)."""
        self._require_admin(principal)
        rows = await self._repository.list_all(limit=limit)
        await self._audit.record(principal, action="user.list", request_id=request_id)
        return [UserResponse.model_validate(row) for row in rows]

    async def invite(
        self, principal: Principal, body: UserInvite, *, request_id: str
    ) -> UserResponse:
        """Invite ``body.email`` — or approve a request, or re-invite a revoked one."""
        self._require_admin(principal)
        row = await self._repository.upsert(
            email=body.email,
            display_name=body.display_name,
            role=body.role,
            status="invited",
            invited_by=principal.email or principal.subject,
        )
        await self._audit.record(
            principal, action="user.invited", request_id=request_id, target=row.email
        )
        return UserResponse.model_validate(row)

    async def set_status(
        self, principal: Principal, *, email: str, status: str, request_id: str
    ) -> UserResponse:
        """Move an existing account to ``status`` (admin only, audited)."""
        self._require_admin(principal)
        row = await self._repository.find_by_email(email)
        if row is None:
            raise NotFoundError(f"no account for {email}")
        row = await self._repository.touch(
            row, seen_at=row.last_seen_at or row.created_at, status=status
        )
        await self._audit.record(
            principal, action=f"user.{status}", request_id=request_id, target=email
        )
        return UserResponse.model_validate(row)

    async def request_access(self, email: str) -> None:
        """Record that ``email`` asked for an invitation; silent if it is known."""
        if await self._repository.find_by_email(email) is None:
            await self._repository.upsert(
                email=email,
                display_name=None,
                role="member",
                status="requested",
                invited_by=None,
            )

    def _require_admin(self, principal: Principal) -> None:
        """Raise unless the caller holds ``admin`` (and MFA when required)."""
        if not principal.has_scope(ADMIN_SCOPE):
            raise AuthorizationError("managing accounts requires the admin scope")
        if self._require_mfa and not principal.is_mfa:
            raise AuthorizationError("managing accounts requires a second factor")


__all__ = ["ADMIN_SCOPE", "UserService"]
