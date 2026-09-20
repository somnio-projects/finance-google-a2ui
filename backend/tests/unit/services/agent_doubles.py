"""Builders shared by the agent-host test modules (turn loop and telemetry)."""

from collections.abc import Sequence

from app.agent.registry import ToolRegistry
from app.core.model import MessageRole, ModelMessage, ModelReply, ToolCall, ToolSpec
from app.core.protocols import ModelClient
from app.helpers.clock import FixedClock
from app.infra.model.null_client import NullModelClient
from app.services.agent_service import AgentService
from tests.conftest import FROZEN_NOW, FakeReporter
from tests.unit.conftest import FakeTool

ANSWER = "Your portfolio is worth $1.00."
#: The prompt these tests assert on. Deliberately not the real one: the turn
#: loop's job is to send whatever prompt it was given, and pinning the real
#: text here would make every prompt edit break the turn-loop suite.
TEST_PROMPT = "test system prompt"


def call(name: str = "fake_tool", *, call_id: str = "0-fake") -> ToolCall:
    """Build a tool call the model could have emitted."""
    return ToolCall(call_id=call_id, name=name, arguments={"top_n": 1})


def make_service(
    model: ModelClient,
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
        system_prompt=TEST_PROMPT,
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
    """A ``ModelClient`` that always raises whatever the test handed it.

    Typed as ``Exception`` rather than ``DependencyUnavailableError`` because
    the adapter has two failure paths to prove: the typed one it reports with
    the error's own code, and the untyped one it must still terminate.
    """

    name = "failing"

    def __init__(self, error: Exception) -> None:
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
