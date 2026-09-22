"""How a unit-test app is built, kept out of `conftest` for the line budget.

`conftest` declares the fixtures; this declares the one factory they all call.
Separated when the session routes and the A2A surface each added their own
client fixture and the single file went past 150 lines.
"""

from datetime import timedelta

from fastapi import FastAPI

from app.agent.registry import load_tools
from app.api.container import AgentRuntime, Container
from app.api.deps import get_portfolio_provider
from app.api.deps.views import get_owner_resolver
from app.bootstrap import create_app
from app.core.config import Settings
from app.core.principal import Principal
from app.domain.persona import PortfolioOwner
from app.domain.provider import InMemoryPortfolioProvider
from app.helpers.clock import FixedClock
from app.infra.db.engine import DatabaseReadinessProbe, create_engine
from app.infra.db.session import create_session_factory
from app.infra.model.null_client import NullModelClient
from app.presentation.registry import REGISTRY
from app.services.agent_card_service import build_agent_card
from app.services.feature_flag_cache import FeatureFlagCache
from app.services.health_service import HealthService
from app.services.prompt_service import build_system_prompt
from tests.conftest import FakeReporter, FakeVerifier


class NoUsers:
    """The users registry as the view path sees it without a database: no one
    is named, so the shell greets the persona (spec 0030 OD-2)."""

    async def owner_for(self, principal: Principal) -> PortfolioOwner | None:
        del principal
        return None


def make_app(
    settings: Settings,
    *,
    principal: Principal,
    clock: FixedClock,
    reporter: FakeReporter,
) -> FastAPI:
    """Create the app with a fake verifier accepting the token ``good``."""
    engine = create_engine(settings)
    tools = load_tools()
    container = Container(
        settings=settings,
        clock=clock,
        reporter=reporter,
        verifier=FakeVerifier(principal),
        engine=engine,
        session_factory=create_session_factory(engine),
        health=HealthService(version="test", probes=[DatabaseReadinessProbe(engine)]),
        flag_cache=FeatureFlagCache(ttl=timedelta(seconds=15), clock=clock),
        agent=AgentRuntime(
            model=NullModelClient(),
            tools=tools,
            system_prompt=build_system_prompt(tools=tools, views=REGISTRY.all()),
            card=build_agent_card(settings, tools, version="test"),
        ),
    )
    app = create_app(settings, container=container)
    # The provider is per request and reads PostgreSQL (spec 0020). Unit tests
    # point at an unreachable DSN on purpose, so the in-memory implementation
    # is substituted here — it exists for exactly this. Anything that needs a
    # row belongs in tests/integration.
    app.dependency_overrides[get_portfolio_provider] = lambda: (
        InMemoryPortfolioProvider(clock=clock)
    )
    app.dependency_overrides[get_owner_resolver] = NoUsers
    return app


__all__ = ["make_app"]
