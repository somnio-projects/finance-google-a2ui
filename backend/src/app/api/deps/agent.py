"""Providers for the agent host (spec 0006).

The A2A controller resolves these. A provider that no controller resolves is
not wiring — GGU-84 was exactly that: `get_render_intent_service` existed,
type-checked and was tested, and no turn ever asked for it. Anything added
here is reached from a route, or it is dead.
"""

from typing import Annotated

from fastapi import Depends

from app.agent.contracts import ToolContext
from app.api.deps.common import (
    ContainerDep,
    PortfolioDep,
    PrincipalDep,
    get_audit_service,
    get_feature_flag_service,
)
from app.api.deps.views import get_render_intent_service
from app.schemas.agent_card import AgentCard
from app.services.a2a_service import A2aService
from app.services.agent_renders import TurnRenderResolver
from app.services.agent_service import AgentService
from app.services.audit_service import AuditService
from app.services.feature_flag_service import FeatureFlagService
from app.services.surface_action_service import SurfaceActionService


def get_agent_service(container: ContainerDep, portfolio: PortfolioDep) -> AgentService:
    """Provide the agent host over the request's portfolio (spec 0006).

    The portfolio provider is the request's own, so the render-intent entry
    point the turn validates through judges a surface with the same registry
    the `?view=` path uses (ADR-K D-11, GGU-84).
    """
    return AgentService(
        model=container.agent.model,
        tools=container.agent.tools,
        reporter=container.reporter,
        renders=TurnRenderResolver(
            intents=get_render_intent_service(container, portfolio)
        ),
        clock=container.clock,
        max_iterations=container.settings.agent_max_tool_iterations,
        system_prompt=container.agent.system_prompt,
    )


def get_tool_context(portfolio: PortfolioDep, principal: PrincipalDep) -> ToolContext:
    """Provide the subject-scoped context every tool of a turn receives."""
    return ToolContext(subject=principal.subject, portfolios=portfolio)


def get_surface_action_service(
    container: ContainerDep,
    flags: Annotated[FeatureFlagService, Depends(get_feature_flag_service)],
    audit: Annotated[AuditService, Depends(get_audit_service)],
) -> SurfaceActionService:
    """Provide the surface-action dispatcher (spec 0022 §3)."""
    return SurfaceActionService(flags=flags, audit=audit, reporter=container.reporter)


def get_a2a_service(container: ContainerDep, portfolio: PortfolioDep) -> A2aService:
    """Provide the A2A protocol adapter over the agent host (ADR-J D-2)."""
    return A2aService(agent=get_agent_service(container, portfolio))


def get_agent_card(container: ContainerDep) -> AgentCard:
    """Provide the agent card built once at startup."""
    return container.agent.card


__all__ = [
    "get_a2a_service",
    "get_agent_card",
    "get_agent_service",
    "get_surface_action_service",
    "get_tool_context",
]
