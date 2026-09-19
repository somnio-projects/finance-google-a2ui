"""Builders shared by the agent-host test modules (turn loop and telemetry)."""

from collections.abc import Sequence

from app.agent.registry import ToolRegistry
from app.core.errors import DependencyUnavailableError
from app.core.model import MessageRole, ModelMessage, ModelReply, ToolCall, ToolSpec
from app.helpers.clock import FixedClock
from app.infra.model.null_client import NullModelClient
from app.services.agent_service import AgentService
from tests.conftest import FROZEN_NOW, FakeReporter
from tests.unit.conftest import FakeTool

ANSWER = "Your portfolio is worth $1.00."


def call(name: str = "fake_tool", *, call_id: str = "0-fake") -> ToolCall:
    """Build a tool call the model could have emitted."""
    return ToolCall(call_id=call_id, name=name, arguments={"top_n": 1})


def make_service(
    model: NullModelClient,
    *,
    tools: Sequence[FakeTool] = (),
    max_iterations: int = 4,
) -> tuple[AgentService, FakeReporter]:
    """Build the service over a fresh registry and a frozen clock."""
    registry = ToolRegistry()
    for tool in tools:
        registry.register(tool)
    reporter = FakeReporter()
    service = AgentService(
        model=model,
        tools=registry,
        reporter=reporter,
        clock=FixedClock(FROZEN_NOW),
        max_iterations=max_iterations,
    )
    return service, reporter


def tool_results(model: NullModelClient) -> list[object]:
    """Every tool result the loop fed back to the model on its last call."""
    return [
        message.tool_result
        for message in model.calls[-1].messages
        if message.role is MessageRole.TOOL
    ]


class FailingModel:
    """A ``ModelClient`` that always fails the way a dead provider does."""

    name = "failing"

    def __init__(self, error: DependencyUnavailableError) -> None:
        self.error = error

    async def generate(
        self,
        *,
        system: str,
        messages: Sequence[ModelMessage],
        tools: Sequence[ToolSpec],
    ) -> ModelReply:
        del system, messages, tools
        raise self.error
