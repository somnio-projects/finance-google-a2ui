"""Request-scoped providers every controller shares.

The container, the correlation id, the unit-of-work session, the caller, and
the services that predate the agent and the presentation layer. Grouped here
so the feature-specific modules beside it stay short enough to read.
"""

from collections.abc import AsyncIterator
from typing import Annotated

from fastapi import Depends, Header, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.api.container import Container
from app.core.principal import Principal
from app.infra.db.session import session_scope
from app.repositories.audit_repository import AuditRepository
from app.repositories.feature_flag_repository import FeatureFlagRepository
from app.repositories.session_repository import SessionRepository
from app.services.audit_service import AuditService
from app.services.auth_service import AuthService
from app.services.feature_flag_service import FeatureFlagService
from app.services.health_service import HealthService
from app.services.identity_service import IdentityService
from app.services.session_service import SessionService


def get_container(request: Request) -> Container:
    """Return the process container placed on ``app.state`` at startup."""
    return request.app.state.container


ContainerDep = Annotated[Container, Depends(get_container)]


def get_request_id(request: Request) -> str:
    """Return the correlation id set by ``RequestIdMiddleware``."""
    return request.state.request_id


RequestIdDep = Annotated[str, Depends(get_request_id)]


def get_health_service(container: ContainerDep) -> HealthService:
    """Provide the singleton health service."""
    return container.health


async def get_session(container: ContainerDep) -> AsyncIterator[AsyncSession]:
    """Provide one unit-of-work session for the request."""
    async with session_scope(container.session_factory) as session:
        yield session


SessionDep = Annotated[AsyncSession, Depends(get_session)]


def get_auth_service(container: ContainerDep) -> AuthService:
    """Provide the auth service bound to the configured verifier."""
    return AuthService(verifier=container.verifier, reporter=container.reporter)


async def get_current_principal(
    auth: Annotated[AuthService, Depends(get_auth_service)],
    authorization: Annotated[
        str | None,
        Header(
            description=(
                "`Bearer <token>` — a Firebase/OIDC ID token, or an HS256 "
                "service token for local and service-to-service use."
            ),
            examples=["Bearer eyJhbGciOiJSUzI1NiIsImtpZCI6..."],
        ),
    ] = None,
) -> Principal:
    """Authenticate the request or raise ``AuthenticationError``."""
    return await auth.authenticate(authorization)


PrincipalDep = Annotated[Principal, Depends(get_current_principal)]


def get_audit_service(session: SessionDep) -> AuditService:
    """Provide the audit service over the request session."""
    return AuditService(repository=AuditRepository(session))


def get_feature_flag_service(
    container: ContainerDep,
    session: SessionDep,
    audit: Annotated[AuditService, Depends(get_audit_service)],
) -> FeatureFlagService:
    """Provide the feature-flag service (shared cache, request session)."""
    return FeatureFlagService(
        repository=FeatureFlagRepository(session),
        cache=container.flag_cache,
        audit=audit,
        reporter=container.reporter,
        force_disabled=container.settings.feature_flags_force_disabled,
        require_mfa=container.settings.admin_mfa_required,
    )


def get_identity_service(
    audit: Annotated[AuditService, Depends(get_audit_service)],
) -> IdentityService:
    """Provide the identity service."""
    return IdentityService(audit=audit)


def get_session_service(
    session: SessionDep,
    audit: Annotated[AuditService, Depends(get_audit_service)],
) -> SessionService:
    """Provide the conversation-session service over the request session."""
    return SessionService(repository=SessionRepository(session), audit=audit)


# No ``__all__`` here on purpose: this module is an internal of the ``deps``
# package, and ``deps/__init__.py`` declares the surface controllers import.
# Restating the same fourteen names in both files gives the next person two
# lists to keep in step and no way to tell which one is authoritative.
