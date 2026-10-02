"""Providers for the A2UI v1.0 surface (ADR-M D-2).

A module of its own, imported by the v1.0 controllers directly, so the v0.9
providers — and ``deps/__init__``'s export list — stay exactly as they were.
Everything here is assembled from providers that already exist: the agent
host, the view service and the surface-action dispatcher are the v0.9 ones,
which is what makes the two wires share one loop and one registry.
"""

from functools import cache
from typing import Annotated

from fastapi import Depends

from app.api.deps.agent import get_agent_service, get_surface_action_service
from app.api.deps.common import ContainerDep, PortfolioDep, PrincipalDep
from app.api.deps.views import OwnersDep, get_view_service
from app.presentation.registry import REGISTRY
from app.schemas.a2ui_v1_card import V1AgentCard
from app.services.a2ui_v1_discovery import build_v1_card, v1_catalog
from app.services.a2ui_v1_payloads import PayloadRenderer
from app.services.a2ui_v1_render_view import RenderViewService
from app.services.a2ui_v1_service import A2uiV1Service
from app.services.a2ui_v1_turn import V1TurnStream
from app.services.surface_action_service import SurfaceActionService


def get_a2ui_v1_service(
    container: ContainerDep,
    portfolio: PortfolioDep,
    owners: OwnersDep,
    principal: PrincipalDep,
    actions: Annotated[SurfaceActionService, Depends(get_surface_action_service)],
) -> A2uiV1Service:
    """Provide the v1.0 protocol adapter over the v0.9 agent host.

    One ``PayloadRenderer`` serves both the turn and ``renderView``, so a
    request reads the caller's portfolio at most once.
    """
    payloads = PayloadRenderer(
        views=get_view_service(portfolio, owners), principal=principal
    )
    return A2uiV1Service(
        turns=V1TurnStream(
            agent=get_agent_service(container, portfolio, owners),
            payloads=payloads,
            reporter=container.reporter,
        ),
        functions=RenderViewService(
            registry=REGISTRY, payloads=payloads, reporter=container.reporter
        ),
        actions=actions,
        reporter=container.reporter,
    )


def get_v1_agent_card(container: ContainerDep) -> V1AgentCard:
    """Provide the v1.0 card, derived from the v0.9 one built at startup."""
    return build_v1_card(container.agent.card)


@cache
def get_v1_catalog() -> str:
    """Provide the generated v1.0 catalog document, rendered once per process.

    The registry is fixed once the views are imported, so the document cannot
    change within a release; re-rendering it per request would be work with
    no possible new answer (presentation.md §5).
    """
    return v1_catalog(REGISTRY.all())


__all__ = ["get_a2ui_v1_service", "get_v1_agent_card", "get_v1_catalog"]
