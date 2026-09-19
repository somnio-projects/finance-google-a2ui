"""Process-wide object graph handed to the API by the composition root.

Stored on ``app.state.container`` so dependencies (``app.api.deps``) can
reach singletons without module-level globals — which keeps tests free to
build many isolated apps in one process.
"""

from dataclasses import dataclass

from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.core.config import Settings
from app.core.protocols import Clock, ErrorReporter, TokenVerifier
from app.services.feature_flag_cache import FeatureFlagCache
from app.services.health_service import HealthService


@dataclass(frozen=True, slots=True)
class Container:
    """Singletons that live for the whole process."""

    settings: Settings
    clock: Clock
    reporter: ErrorReporter
    verifier: TokenVerifier
    engine: AsyncEngine
    session_factory: async_sessionmaker[AsyncSession]
    health: HealthService
    flag_cache: FeatureFlagCache


__all__ = ["Container"]
