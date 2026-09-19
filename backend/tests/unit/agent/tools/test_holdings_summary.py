"""Spec 0006 AC-8 — the reference tool returns display strings, never raw numbers."""

import re

import pytest
from pydantic import ValidationError

from app.agent.contracts import ToolContext
from app.agent.tools.holdings_summary import VIEW, HoldingsSummaryTool

DISPLAY_KEY = re.compile(r"Display$")


@pytest.fixture
def tool() -> HoldingsSummaryTool:
    return HoldingsSummaryTool()


async def test_run_returns_every_seeded_position_largest_first(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    outcome = await tool.run({}, tool_context)
    holdings = outcome.data["holdings"]
    assert isinstance(holdings, list)

    expected = sorted(
        tool_context.portfolios.get(tool_context.subject).holdings(),
        key=lambda item: item.market_value,
        reverse=True,
    )
    assert [row["symbol"] for row in holdings] == [item.symbol for item in expected]
    assert outcome.data["positionCount"] == len(expected)


async def test_run_formats_every_figure_and_leaks_no_raw_number(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    outcome = await tool.run({}, tool_context)
    holdings = outcome.data["holdings"]
    assert isinstance(holdings, list)

    numeric_top_level = {
        key
        for key, value in outcome.data.items()
        if isinstance(value, (int, float)) and not isinstance(value, bool)
    }
    assert numeric_top_level == {"positionCount"}
    for row in holdings:
        assert all(isinstance(value, str) for value in row.values())
        formatted = {key for key in row if DISPLAY_KEY.search(key)}
        assert formatted == set(row) - {"symbol", "name"}


async def test_run_totals_agree_with_the_domain(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    portfolio = tool_context.portfolios.get(tool_context.subject)
    total = sum(item.market_value for item in portfolio.holdings())

    outcome = await tool.run({}, tool_context)

    assert outcome.data["totalMarketValueDisplay"] == f"${total:,.2f}"
    assert outcome.data["asOf"] == portfolio.as_of.isoformat()


async def test_run_with_top_n_keeps_only_the_largest_positions(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    full = await tool.run({}, tool_context)
    trimmed = await tool.run({"top_n": 1}, tool_context)
    holdings = trimmed.data["holdings"]
    assert isinstance(holdings, list)
    all_holdings = full.data["holdings"]
    assert isinstance(all_holdings, list)

    assert len(holdings) == 1
    assert holdings[0] == all_holdings[0]
    # The count still describes the portfolio, not the slice.
    assert trimmed.data["positionCount"] == full.data["positionCount"]


async def test_run_emits_the_allocation_render_intent(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    outcome = await tool.run({"top_n": 2}, tool_context)

    assert outcome.render is not None
    assert outcome.render.view == VIEW
    assert outcome.render.options == {"top_n": 2}


@pytest.mark.parametrize(
    "arguments",
    [{"top_n": 0}, {"top_n": 99}, {"unknown": 1}, {"top_n": "two"}],
    ids=["below_bound", "above_bound", "undeclared_option", "wrong_type"],
)
async def test_run_rejects_arguments_the_schema_does_not_declare(
    tool: HoldingsSummaryTool,
    tool_context: ToolContext,
    arguments: dict[str, object],
) -> None:
    with pytest.raises(ValidationError, match=r"top_n|unknown"):
        await tool.run(arguments, tool_context)
