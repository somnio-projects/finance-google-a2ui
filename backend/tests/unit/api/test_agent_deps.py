"""Spec 0006 — the agent host is wired, even before a route resolves it.

GGU-3 adds the controller and GGU-46 the history; the providers exist now so
both land as a controller rather than as a second wiring path. A turn is run
through them end to end: with no ``GEMINI_API_KEY`` the container holds the
null client, so the service answers deterministically and opens no socket.
"""

from fastapi import FastAPI

from app.api.deps import get_agent_service, get_tool_context
from app.core.principal import Principal
from app.domain.provider import InMemoryPortfolioProvider
from app.helpers.clock import FixedClock
from app.infra.model.null_client import UNCONFIGURED_MESSAGE
from app.services.agent_service import AgentService
from tests.conftest import FROZEN_NOW


def test_get_tool_context_scopes_the_context_to_the_caller(
    app: FastAPI, principal: Principal, clock: FixedClock
) -> None:
    """The context carries the caller's subject and the provider it was given.

    The provider arrives as a per-request argument since spec 0020 — it holds
    a repository over the request's session — so this asserts the wiring
    passes through exactly what it was handed, which is the only thing this
    dependency is responsible for.
    """
    portfolio = InMemoryPortfolioProvider(clock=clock)

    context = get_tool_context(portfolio, principal)

    assert context.subject == principal.subject
    assert context.portfolios is portfolio


async def test_the_wired_service_runs_a_turn_against_the_configured_model(
    app: FastAPI, principal: Principal
) -> None:
    container = app.state.container
    portfolio = InMemoryPortfolioProvider(clock=FixedClock(FROZEN_NOW))
    service = get_agent_service(container, portfolio)

    result = await service.run_turn(
        prompt="what do I hold?",
        history=[],
        context=get_tool_context(portfolio, principal),
    )

    assert isinstance(service, AgentService)
    assert result.message == UNCONFIGURED_MESSAGE
    assert result.iterations == 1
    assert result.tool_calls == 0
    # The registry the container holds is the discovered one, not an empty stub.
    assert "get_holdings_summary" in container.agent.tools.names()
