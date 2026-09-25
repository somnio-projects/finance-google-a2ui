"""Spec 0032 — the drill-down tool hands the model strings and asks for the card."""

import re

import pytest
from pydantic import ValidationError

from app.agent.contracts import ToolContext
from app.agent.tools.driver_detail import NAME, VIEW, DriverDetailTool
from app.domain.driver import driver_detail

DISPLAY_KEY = re.compile(r"Display$")
#: The keys that are words or facts about the answer, not figures.
WORD_KEYS = frozenset({"held", "asOf", "symbol", "name", "standing", "rank", "trend"})


@pytest.fixture
def tool() -> DriverDetailTool:
    return DriverDetailTool()


async def test_run_describes_the_holding_and_asks_for_its_card(
    tool: DriverDetailTool, tool_context: ToolContext
) -> None:
    outcome = await tool.run({"symbol": "BTC"}, tool_context)

    assert outcome.data["held"] is True
    assert (outcome.data["symbol"], outcome.data["name"]) == ("BTC", "Bitcoin")
    assert (outcome.data["standing"], outcome.data["rank"]) == ("top_contributor", 1)
    assert outcome.render is not None
    assert outcome.render.view == VIEW
    assert outcome.render.options == {"symbol": "BTC"}


async def test_every_figure_the_model_sees_is_a_display_string(
    tool: DriverDetailTool, tool_context: ToolContext
) -> None:
    """Numbers-from-tools: no bare figure reaches the model (spec 0006 AC-8)."""
    outcome = await tool.run({"symbol": "BTC"}, tool_context)

    for key, value in outcome.data.items():
        if key in WORD_KEYS:
            continue
        assert DISPLAY_KEY.search(key), f"{key} is not a display field"
        assert isinstance(value, str), f"{key} reached the model as {type(value)}"
    assert outcome.data["contributionDisplay"] == "+$4,767.00"
    assert outcome.data["priceMovePctDisplay"] == "+3.66%"
    assert outcome.data["sharesDisplay"] == "2.1"
    assert outcome.data["priceDisplay"] == "$64,250.00"
    assert outcome.data["dayGainDisplay"] == "+$2,201.05"


async def test_the_tool_and_the_card_read_one_computation(
    tool: DriverDetailTool, tool_context: ToolContext
) -> None:
    """What the model says and what the card shows come from the same domain result."""
    outcome = await tool.run({"symbol": "aave"}, tool_context)
    portfolio = await tool_context.portfolios.get(tool_context.owner)
    detail = driver_detail(portfolio, "AAVE")

    assert detail is not None
    assert outcome.data["standing"] == detail.standing == "top_detractor"
    assert outcome.data["trend"] == "down"
    assert outcome.render is not None
    assert outcome.render.options == {"symbol": "AAVE"}  # normalised, not echoed


async def test_a_symbol_the_portfolio_does_not_hold_is_the_leaf(
    tool: DriverDetailTool, tool_context: ToolContext
) -> None:
    """Answered, not failed: the model is told there is nothing to break down."""
    outcome = await tool.run({"symbol": "AVAX"}, tool_context)

    assert outcome.data == {"symbol": "AVAX", "held": False}
    assert outcome.render is None


@pytest.mark.parametrize(
    "arguments",
    [{}, {"symbol": "NOT-A-TICKER"}, {"symbol": "BTC", "window": "7d"}],
    ids=["missing", "malformed", "undeclared_argument"],
)
async def test_an_argument_the_schema_does_not_declare_is_rejected(
    tool: DriverDetailTool, tool_context: ToolContext, arguments: dict[str, object]
) -> None:
    with pytest.raises(ValidationError):
        await tool.run(arguments, tool_context)


def test_it_describes_itself_for_the_model_to_choose_by(tool: DriverDetailTool) -> None:
    properties = tool.parameters["properties"]

    assert tool.name == NAME
    assert "driver" in tool.description.lower()
    assert isinstance(properties, dict)
    assert set(properties) == {"symbol"}
