"""Providers for the presentation layer (spec 0005).

Both entry points to the projection registry live here: the client-facing one
(``?view=``) and the agent-facing render intent, so the two callers of ADR-K
are visibly the same path.
"""

from app.api.deps.common import ContainerDep, PortfolioDep
from app.presentation.registry import REGISTRY
from app.services.render_intent_service import RenderIntentService
from app.services.view_render_service import ViewRenderService
from app.services.view_service import ViewService


def get_view_service(portfolio: PortfolioDep) -> ViewService:
    """Provide the projection renderer over the caller's portfolio (0005 AC-6).

    The registry is filled by importing ``app.presentation.views``, which the
    controller module does at import time — see ``api/v1/portfolio_views.py``.
    """
    return ViewService(provider=portfolio, registry=REGISTRY)


def get_render_intent_service(
    container: ContainerDep, portfolio: PortfolioDep
) -> RenderIntentService:
    """Provide the agent-facing render-intent entry point (GGU-47 calls it)."""
    return RenderIntentService(
        views=get_view_service(portfolio), reporter=container.reporter
    )


def get_view_render_service(portfolio: PortfolioDep) -> ViewRenderService:
    """Provide the batch render resource's service (ADR-K D-18, 0012 AC-4)."""
    return ViewRenderService(views=get_view_service(portfolio))


__all__ = [
    "get_render_intent_service",
    "get_view_render_service",
    "get_view_service",
]
