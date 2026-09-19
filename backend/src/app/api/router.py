"""Aggregate every controller into one router mounted by the app factory."""

from fastapi import APIRouter

from app.api.v1 import feature_flags, health, identity

api_router = APIRouter()
api_router.include_router(health.router)
api_router.include_router(identity.router)
api_router.include_router(feature_flags.router)

__all__ = ["api_router"]
