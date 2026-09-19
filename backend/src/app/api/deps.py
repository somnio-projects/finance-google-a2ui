"""FastAPI dependency providers.

Every controller parameter comes from here, so wiring is visible in one file
and services stay ignorant of HTTP.
"""

from collections.abc import AsyncIterator
from typing import Annotated

from fastapi import Depends, Header, Request
from sqlalchemy.ext.asyncio import AsyncSession

from app.agent.contracts import ToolContext
from app.api.container import Container
from app.core.principal import Principal
from app.infra.db.session import session_scope
from app.presentation.registry import REGISTRY
from app.repositories.audit_repository import AuditRepository
from app.repositories.feature_flag_repository import FeatureFlagRepository
from app.services.agent_service import AgentService
from app.services.audit_service import AuditService
from app.services.auth_service import AuthService
from app.services.feature_flag_service import FeatureFlagService
from app.services.health_service import HealthService
from app.services.identity_service import IdentityService
from app.services.render_intent_service import RenderIntentService
from app.services.view_service import ViewService


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


def get_view_service(container: ContainerDep) -> ViewService:
    """Provide the projection renderer over the caller's portfolio (0005 AC-6).

    The registry is filled by importing ``app.presentation.views``, which the
    controller module does at import time — see ``api/v1/portfolio_views.py``.
    """
    return ViewService(provider=container.portfolio, registry=REGISTRY)


def get_render_intent_service(container: ContainerDep) -> RenderIntentService:
    """Provide the agent-facing render-intent entry point (GGU-47 calls it)."""
    return RenderIntentService(
        views=get_view_service(container), reporter=container.reporter
    )


def get_identity_service(
    audit: Annotated[AuditService, Depends(get_audit_service)],
) -> IdentityService:
    """Provide the identity service."""
    return IdentityService(audit=audit)


def get_agent_service(container: ContainerDep) -> AgentService:
    """Provide the agent host (spec 0006).

    No route resolves it yet: GGU-3 exposes the turn over the A2A surface and
    GGU-46 supplies the history. The provider lives here so both land as a
    controller, not as a second wiring path.
    """
    return AgentService(
        model=container.agent.model,
        tools=container.agent.tools,
        reporter=container.reporter,
        clock=container.clock,
        max_iterations=container.settings.agent_max_tool_iterations,
    )


def get_tool_context(container: ContainerDep, principal: PrincipalDep) -> ToolContext:
    """Provide the subject-scoped context every tool of a turn receives."""
    return ToolContext(subject=principal.subject, portfolios=container.portfolio)


__all__ = [
    "ContainerDep",
    "PrincipalDep",
    "RequestIdDep",
    "SessionDep",
    "get_agent_service",
    "get_audit_service",
    "get_auth_service",
    "get_container",
    "get_current_principal",
    "get_feature_flag_service",
    "get_health_service",
    "get_identity_service",
    "get_render_intent_service",
    "get_request_id",
    "get_session",
    "get_tool_context",
    "get_view_service",
]
