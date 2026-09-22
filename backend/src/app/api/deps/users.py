"""Providers for the provisioning services (spec 0027)."""

from typing import Annotated

from fastapi import Depends

from app.api.deps.common import ContainerDep, SessionDep, get_audit_service
from app.repositories.user_repository import UserRepository
from app.services.audit_service import AuditService
from app.services.preview_sign_in_service import PreviewSignInService
from app.services.user_service import UserService

AuditDep = Annotated[AuditService, Depends(get_audit_service)]


def get_user_service(
    container: ContainerDep, session: SessionDep, audit: AuditDep
) -> UserService:
    """Provide the provisioning service over the request session."""
    return UserService(
        repository=UserRepository(session),
        audit=audit,
        clock=container.clock,
        require_mfa=container.settings.admin_mfa_required,
    )


#: The provisioning service, resolved per request.
UsersDep = Annotated[UserService, Depends(get_user_service)]


def get_preview_sign_in_service(
    container: ContainerDep, session: SessionDep, audit: AuditDep
) -> PreviewSignInService:
    """Provide the local e-mail sign-in over the request session."""
    return PreviewSignInService(
        repository=UserRepository(session),
        audit=audit,
        clock=container.clock,
        settings=container.settings,
    )


__all__ = ["AuditDep", "UsersDep", "get_preview_sign_in_service", "get_user_service"]
