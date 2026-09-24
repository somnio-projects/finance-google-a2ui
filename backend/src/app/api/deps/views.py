"""Providers for the presentation layer (spec 0005).

Both entry points to the projection registry live here: the client-facing one
(``?view=``) and the agent-facing render intent, so the two callers of ADR-K
are visibly the same path.
"""

from typing import Annotated

from fastapi import Depends

from app.api.deps.common import ContainerDep, PortfolioDep
from app.api.deps.users import UsersDep
from app.presentation.registry import REGISTRY
from app.services.render_intent_service import RenderIntentService
from app.services.view_render_service import ViewRenderService
from app.services.view_service import OwnerResolver, ViewService


def get_owner_resolver(users: UsersDep) -> OwnerResolver:
    """Who the shell greets: the users registry names the caller (spec 0030).

    Its own dependency, rather than the user service itself, so a unit test of
    the view routes can name nobody without touching the access routes.
    """
    return users


#: The greeting's source, resolved per request.
OwnersDep = Annotated[OwnerResolver, Depends(get_owner_resolver)]


def get_view_service(portfolio: PortfolioDep, owners: OwnersDep) -> ViewService:
    """Provide the projection renderer over the caller's portfolio (0005 AC-6).

    The registry is filled by importing ``app.presentation.views``, which the
    controller module does at import time — see ``api/v1/portfolio_views.py``.
    """
    return ViewService(provider=portfolio, registry=REGISTRY, owners=owners)


def get_render_intent_service(
    container: ContainerDep, portfolio: PortfolioDep, owners: OwnersDep
) -> RenderIntentService:
    """Provide the agent-facing render-intent entry point (GGU-47 calls it)."""
    return RenderIntentService(
        views=get_view_service(portfolio, owners), reporter=container.reporter
    )


def get_view_render_service(
    portfolio: PortfolioDep, owners: OwnersDep
) -> ViewRenderService:
    """Provide the batch render resource's service (ADR-K D-18, 0012 AC-4)."""
    return ViewRenderService(views=get_view_service(portfolio, owners))


__all__ = [
    "OwnersDep",
    "get_owner_resolver",
    "get_render_intent_service",
    "get_view_render_service",
    "get_view_service",
]
