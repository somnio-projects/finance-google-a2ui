"""Process-wide object graph handed to the API by the composition root.

Stored on ``app.state.container`` so dependencies (``app.api.deps``) can
reach singletons without module-level globals — which keeps tests free to
build many isolated apps in one process.
"""

from dataclasses import dataclass

from sqlalchemy.ext.asyncio import AsyncEngine, AsyncSession, async_sessionmaker

from app.agent.registry import ToolRegistry
from app.core.config import Settings
from app.core.protocols import Clock, ErrorReporter, ModelClient, TokenVerifier
from app.schemas.agent_card import AgentCard
from app.services.feature_flag_cache import FeatureFlagCache
from app.services.health_service import HealthService


@dataclass(frozen=True, slots=True)
class AgentRuntime:
    """The agent host's process-wide collaborators (spec 0006).

    Grouped rather than spread across the container: they are built together,
    replaced together in tests, and neither is meaningful without the other.

    The portfolio provider is deliberately *not* here either — and no longer
    anywhere process-wide. It holds a repository over the request's session,
    whose commit `session_scope` owns, so it is built in `api/deps/common.py`
    per request (spec 0020 §4.2).
    """

    model: ModelClient
    tools: ToolRegistry
    system_prompt: str
    card: AgentCard


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
    agent: AgentRuntime


__all__ = ["AgentRuntime", "Container"]
