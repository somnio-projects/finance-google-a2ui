"""Spec 0058 AC-3/AC-10 — a failed model call is still counted, and named."""

from collections.abc import Sequence

import pytest
import structlog

from app.agent.contracts import ToolContext
from app.core.model import ModelMessage, ModelReply, ToolSpec
from app.core.model_errors import (
    MODEL_OUT_OF_CREDIT,
    MODEL_UNAVAILABLE,
    ModelOutOfCreditError,
    ModelProviderError,
)
from app.core.model_usage import TokenUsage
from app.services.agent_service import TURN_METRIC
from tests.unit.conftest import FakeTool
from tests.unit.services.agent_doubles import (
    FailingModel,
    call,
    make_service,
    turn_line,
)

BILLED = TokenUsage(prompt=4500, candidates=200, billed_calls=2)


class FailsOnSecondCall:
    """Ask for a tool on a call that billed, then fail with ``failure``."""

    name = "gemini-3.8-flash"

    def __init__(self, failure: ModelProviderError) -> None:
        self.failure = failure
        self.calls = 0

    async def generate(
        self,
        *,
        system: str,
        messages: Sequence[ModelMessage],
        tools: Sequence[ToolSpec],
    ) -> ModelReply:
        del system, messages, tools
        self.calls += 1
        if self.calls > 1:
            raise self.failure
        return ModelReply(tool_calls=(call(),), usage=BILLED)


@pytest.mark.parametrize(
    ("failure", "outcome"),
    [
        (ModelOutOfCreditError(usage=BILLED), MODEL_OUT_OF_CREDIT),
        (ModelProviderError(usage=BILLED), MODEL_UNAVAILABLE),
    ],
    ids=["402", "any-other-provider-failure"],
)
async def test_a_failed_model_call_is_counted_and_named(
    tool_context: ToolContext, failure: ModelProviderError, outcome: str
) -> None:
    service, reporter = make_service(FailingModel(failure))

    with structlog.testing.capture_logs() as logs:
        with pytest.raises(ModelProviderError, match="model provider unavailable"):
            await service.run_turn(prompt="hi", history=[], context=tool_context)

    line = turn_line(logs)
    assert line["outcome"] == outcome
    assert line["model_calls_billed"] == 2
    assert line["tokens_input"] == 4500
    assert reporter.metrics == [
        (TURN_METRIC, {"model": "failing", "outcome": outcome, "composed": "False"})
    ]


async def test_a_turn_that_fails_late_keeps_what_its_earlier_calls_billed(
    tool_context: ToolContext, fake_tool: FakeTool
) -> None:
    """The first call billed and ran a tool; the second ran out of credit."""
    model = FailsOnSecondCall(ModelOutOfCreditError(usage=BILLED))
    service, _ = make_service(model, tools=[fake_tool])

    with structlog.testing.capture_logs() as logs:
        with pytest.raises(ModelOutOfCreditError, match="model provider unavailable"):
            await service.run_turn(prompt="hi", history=[], context=tool_context)

    line = turn_line(logs)
    assert model.calls == 2
    assert line["outcome"] == MODEL_OUT_OF_CREDIT
    assert line["model_calls_billed"] == 4
    assert line["tokens_input"] == 9000
    # 9000 · 0.75 + 400 · 3.75, per million
    assert line["estimated_cost_usd"] == 0.00825
