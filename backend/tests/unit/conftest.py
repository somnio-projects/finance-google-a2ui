"""Unit-suite marker, plus the doubles the agent-host tests share."""

import uuid
from collections.abc import Mapping

import pytest

from app.agent.contracts import RenderIntent, ToolContext, ToolOutcome
from app.domain.provider import InMemoryPortfolioProvider
from app.helpers.clock import FixedClock
from tests.conftest import FROZEN_NOW


def pytest_collection_modifyitems(items: list[pytest.Item]) -> None:
    for item in items:
        if "/tests/unit/" in str(item.fspath):
            item.add_marker(pytest.mark.unit)


class FakeTool:
    """A tool returning a canned outcome, or raising whatever it was given."""

    name = "fake_tool"
    description = "Return whatever the test scripted."
    parameters: Mapping[str, object] = {"type": "object", "properties": {}}

    def __init__(
        self,
        *,
        outcome: ToolOutcome | None = None,
        error: Exception | None = None,
    ) -> None:
        self.outcome = outcome or ToolOutcome(
            data={"answerDisplay": "$1.00"},
            render=RenderIntent(view="holdings.allocation.v1", options={}),
        )
        self.error = error
        self.seen: list[Mapping[str, object]] = []

    async def run(
        self, arguments: Mapping[str, object], context: ToolContext
    ) -> ToolOutcome:
        self.seen.append(dict(arguments))
        del context
        if self.error is not None:
            raise self.error
        return self.outcome


@pytest.fixture
def tool_context() -> ToolContext:
    return ToolContext(
        subject=f"user-{uuid.uuid4()}",
        portfolios=InMemoryPortfolioProvider(clock=FixedClock(FROZEN_NOW)),
    )


@pytest.fixture
def fake_tool() -> FakeTool:
    return FakeTool()
