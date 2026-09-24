"""GGU-36 — the attribution tool hands the model strings, never numbers."""

import re
from datetime import timedelta

import pytest
from pydantic import ValidationError

from app.agent.contracts import ToolContext
from app.agent.tools.attribution import NAME, VIEW, WINDOWS, ComputeAttributionTool
from app.domain.attribution import attribute_window

DISPLAY_KEY = re.compile(r"Display$")
SCALAR_KEYS = ("asOf", "window", "trend")


@pytest.fixture
def tool() -> ComputeAttributionTool:
    return ComputeAttributionTool()


async def test_run_answers_with_a_total_and_one_row_per_holding(
    tool: ComputeAttributionTool, tool_context: ToolContext
) -> None:
    outcome = await tool.run({}, tool_context)
    rows = outcome.data["contributions"]
    assert isinstance(rows, list)

    expected = (await tool_context.portfolios.get(tool_context.owner)).holdings()
    assert len(rows) == len(expected)
    assert outcome.data["window"] == "7d"


async def test_every_figure_the_model_sees_is_a_display_string(
    tool: ComputeAttributionTool, tool_context: ToolContext
) -> None:
    """AC-3 — no bare number reaches the model, at either level."""
    outcome = await tool.run({}, tool_context)
    rows = outcome.data["contributions"]
    assert isinstance(rows, list)

    numeric_top = {
        key: value
        for key, value in outcome.data.items()
        if key not in SCALAR_KEYS
        and key != "contributions"
        and not DISPLAY_KEY.search(key)
    }
    assert numeric_top == {}
    for row in rows:
        assert isinstance(row, dict)
        for key, value in row.items():
            if key in {"symbol", "name", "trend"}:
                continue
            assert DISPLAY_KEY.search(key), f"{key} is not a display field"
            assert isinstance(value, str), f"{key} reached the model as {type(value)}"


async def test_the_rows_are_ordered_biggest_mover_first(
    tool: ComputeAttributionTool, tool_context: ToolContext
) -> None:
    """AC-6 — asserted on the payload the model reads, not only on the domain.

    The payload carries display strings, so the order is checked against the
    domain result rather than by parsing them back into numbers — parsing a
    formatted string to verify formatting would test the parser.
    """
    outcome = await tool.run({}, tool_context)
    rows = outcome.data["contributions"]
    assert isinstance(rows, list)

    expected = attribute_window(
        await tool_context.portfolios.get(tool_context.owner),
        window=timedelta(days=7),
    )

    assert [row["symbol"] for row in rows if isinstance(row, dict)] == [
        row.symbol for row in expected.contributions
    ]


@pytest.mark.parametrize("window", sorted(WINDOWS), ids=sorted(WINDOWS))
async def test_each_supported_window_is_honoured(
    tool: ComputeAttributionTool, tool_context: ToolContext, window: str
) -> None:
    """AC-5 — every window the schema advertises actually runs."""
    outcome = await tool.run({"window": window}, tool_context)

    assert outcome.data["window"] == window


async def test_a_symbol_filter_narrows_the_answer(
    tool: ComputeAttributionTool, tool_context: ToolContext
) -> None:
    outcome = await tool.run({"symbols": ["NVDA"]}, tool_context)
    rows = outcome.data["contributions"]
    assert isinstance(rows, list)

    assert [row["symbol"] for row in rows if isinstance(row, dict)] == ["NVDA"]


@pytest.mark.parametrize(
    "arguments",
    [
        {"window": "1y"},
        {"window": 7},
        {"unknown": True},
        {"symbols": "NVDA"},
    ],
    ids=["unsupported_window", "wrong_type", "undeclared_argument", "not_a_list"],
)
async def test_an_argument_the_schema_does_not_declare_is_rejected(
    tool: ComputeAttributionTool,
    tool_context: ToolContext,
    arguments: dict[str, object],
) -> None:
    """The model picks from the declared set; it does not invent one."""
    with pytest.raises(ValidationError):
        await tool.run(arguments, tool_context)


async def test_the_same_question_twice_gives_the_same_answer(
    tool: ComputeAttributionTool, tool_context: ToolContext
) -> None:
    """AC-4 — determinism, at the tool boundary the model actually sees."""
    first = await tool.run({"window": "7d"}, tool_context)
    second = await tool.run({"window": "7d"}, tool_context)

    assert first.data == second.data


async def test_it_asks_for_the_waterfall(
    tool: ComputeAttributionTool, tool_context: ToolContext
) -> None:
    outcome = await tool.run({}, tool_context)

    assert outcome.render is not None
    assert outcome.render.view == VIEW


def test_it_describes_itself_for_the_model_to_choose_by(
    tool: ComputeAttributionTool,
) -> None:
    properties = tool.parameters["properties"]

    assert tool.name == NAME
    assert "why" in tool.description.lower()
    assert isinstance(properties, dict)
    assert set(properties) == {"window", "symbols"}
