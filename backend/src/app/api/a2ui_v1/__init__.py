"""The A2UI v1.0 surface, mounted under ``/a2ui/v1`` (ADR-M D-2).

One router for the whole prefix, so the composition point gains one include
line and the v0.9 routes beside it do not move.
"""

from fastapi import APIRouter

from app.api.a2ui_v1 import discovery, rpc

router = APIRouter(prefix="/a2ui/v1")
router.include_router(discovery.router)
router.include_router(rpc.router)

__all__ = ["router"]
