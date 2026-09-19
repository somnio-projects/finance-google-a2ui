"""The ``/v1/me`` use case: describe the caller and audit the access."""

from app.core.principal import Principal
from app.schemas.identity import MeResponse
from app.services.audit_service import AuditService


class IdentityService:
    """Compose the identity view and record the access in the audit trail."""

    def __init__(self, *, audit: AuditService) -> None:
        """Inject the audit service (request-scoped)."""
        self._audit = audit

    async def describe(self, principal: Principal, *, request_id: str) -> MeResponse:
        """Return the caller's identity after recording an ``identity.read``."""
        await self._audit.record(
            principal, action="identity.read", request_id=request_id
        )
        return MeResponse(
            subject=principal.subject,
            provider=principal.provider,
            email=principal.email,
            scopes=sorted(principal.scopes),
        )


__all__ = ["IdentityService"]
