"""Spec 0058 AC-4/AC-8/AC-9 — a turn sums what it spent and says what it cost."""

from datetime import UTC, datetime

import structlog

from app.actions.contracts import DirectCall
from app.agent.contracts import ToolContext
from app.core.model import ModelReply
from app.core.model_usage import TokenUsage
from app.infra.model.null_client import NullModelClient
from tests.unit.conftest import FakeTool
from tests.unit.services.agent_doubles import (
    ANSWER,
    PricedModel,
    call,
    make_service,
    turn_line,
)

FIRST = TokenUsage(
    prompt=4000, cached=1000, candidates=100, thoughts=400, billed_calls=1
)
SECOND = TokenUsage(prompt=4500, candidates=200, thoughts=0, billed_calls=2)


async def test_a_turn_sums_every_model_call_and_prices_it(
    tool_context: ToolContext, fake_tool: FakeTool
) -> None:
    model = PricedModel(
        [
            ModelReply(tool_calls=(call(),), usage=FIRST),
            ModelReply(text=ANSWER, usage=SECOND),
        ]
    )
    service, _ = make_service(model, tools=[fake_tool])

    with structlog.testing.capture_logs() as logs:
        await service.run_turn(prompt="hi", history=[], context=tool_context)

    line = turn_line(logs)
    assert line["tokens_input"] == 8500
    assert line["tokens_cached"] == 1000
    assert line["tokens_output"] == 300
    assert line["tokens_thinking"] == 400
    assert line["model_calls_billed"] == 3
    # 7500 · 0.75 + 1000 · 0.075 + 700 · 3.75, per million = 0.008325
    assert line["estimated_cost_usd"] == 0.008325
    assert isinstance(line["estimated_cost_usd"], float)
    assert line["price_missing"] is False


async def test_the_turns_own_date_picks_the_price_band(
    tool_context: ToolContext,
) -> None:
    usage = TokenUsage(prompt=1_000_000, billed_calls=1)
    model = PricedModel([ModelReply(text=ANSWER, usage=usage)])
    service, _ = make_service(model, now=datetime(2027, 1, 1, 0, 0, tzinfo=UTC))

    with structlog.testing.capture_logs() as logs:
        await service.run_turn(prompt="hi", history=[], context=tool_context)

    assert turn_line(logs)["estimated_cost_usd"] == 1.5


async def test_a_turn_on_an_unpriced_model_flags_it_instead_of_guessing(
    tool_context: ToolContext,
) -> None:
    service, _ = make_service(NullModelClient([ModelReply(text=ANSWER, usage=FIRST)]))

    with structlog.testing.capture_logs() as logs:
        await service.run_turn(prompt="hi", history=[], context=tool_context)

    line = turn_line(logs)
    assert line["estimated_cost_usd"] is None
    assert line["price_missing"] is True
    assert line["tokens_input"] == 4000


async def test_a_direct_turn_spends_nothing(
    tool_context: ToolContext, fake_tool: FakeTool
) -> None:
    """Spec 0056 asks no model, so 0058 AC-4 says it costs nothing."""
    model = PricedModel()
    service, _ = make_service(model, tools=[fake_tool])
    direct = DirectCall(tool=fake_tool.name, arguments={}, answer=lambda _: ANSWER)

    with structlog.testing.capture_logs() as logs:
        async for _ in service.run_turn_events(
            prompt="drill", history=[], context=tool_context, direct=direct
        ):
            pass

    line = turn_line(logs)
    assert model.calls == []
    assert line["model_calls_billed"] == 0
    assert line["estimated_cost_usd"] == 0.0
    assert line["price_missing"] is False
