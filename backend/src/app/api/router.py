"""Aggregate every controller into one router mounted by the app factory.

This is the single registration point for HTTP routes. To add endpoints:

1. create ``app/api/v1/<domain>.py`` owning one ``APIRouter`` (prefix + tags),
2. add its ``get_<domain>_service`` provider in ``app/api/deps.py``,
3. ``include_router`` it below, keeping the list alphabetical after ``health``.

Controllers never import each other; ``docs/ADDING_AN_ENDPOINT.md`` has the
full recipe and the controller template.
"""

from fastapi import APIRouter

from app.api import a2a, agent_card
from app.api.v1 import (
    feature_flags,
    health,
    identity,
    portfolio_views,
    view_renders,
    views,
)

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(feature_flags.router)
api_router.include_router(identity.router)
api_router.include_router(portfolio_views.router)
api_router.include_router(view_renders.router)
api_router.include_router(views.router)
# Last on purpose: the A2A surface owns `/` and a well-known path, and is the
# only non-RESTful router here (ADR-J).
api_router.include_router(agent_card.router)
api_router.include_router(a2a.router)

__all__ = ["api_router"]
