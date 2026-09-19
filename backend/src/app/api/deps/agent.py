"""Providers for the agent host (spec 0006).

No route resolves these yet — GGU-3 exposes the turn over the A2A surface
(ADR-J D-2). They live here rather than inside that future controller so the
transport lands as a controller, not as a second wiring path.
"""

from app.agent.contracts import ToolContext
from app.api.deps.common import ContainerDep, PrincipalDep
from app.services.agent_service import AgentService


def get_agent_service(container: ContainerDep) -> AgentService:
    """Provide the agent host (spec 0006).

    No route resolves it yet: GGU-3 exposes the turn over the A2A surface and
    GGU-46 supplies the history. The provider lives here so both land as a
    controller, not as a second wiring path.
    """
    return AgentService(
        model=container.agent.model,
        tools=container.agent.tools,
        reporter=container.reporter,
        clock=container.clock,
        max_iterations=container.settings.agent_max_tool_iterations,
    )


def get_tool_context(container: ContainerDep, principal: PrincipalDep) -> ToolContext:
    """Provide the subject-scoped context every tool of a turn receives."""
    return ToolContext(subject=principal.subject, portfolios=container.agent.portfolios)


__all__ = ["get_agent_service", "get_tool_context"]
