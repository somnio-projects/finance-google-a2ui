"""Spec 0011 — what the holdings tool answers.

Which positions, in which order, is ``test_holdings_ordering``; this file is
the payload: the totals, the formatting invariant, determinism and the render
intent.
"""

import re

from app.agent.contracts import ToolContext
from app.agent.tools.holdings_summary import VIEW, HoldingsSummaryTool
from app.domain.invariants import WEIGHT_TOLERANCE
from app.domain.money import ONE, ZERO
from tests.unit.agent.tools.holdings_fixtures import held, rows, tool

__all__ = ["tool"]

DISPLAY_KEY = re.compile(r"Display$")
NOT_A_FIGURE = frozenset({"symbol", "name", "trend"})


async def test_it_describes_itself_for_the_model_to_choose_by(
    tool: HoldingsSummaryTool,
) -> None:
    """AC-1 — the description and the schema are what the model picks from."""
    assert tool.name == "get_holdings_summary"
    assert "gainers" in tool.description
    properties = tool.parameters["properties"]
    assert isinstance(properties, dict)
    assert set(properties) == {"sort_by", "symbols", "top_n"}
    assert tool.parameters["additionalProperties"] is False


async def test_the_totals_agree_with_the_domain(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """AC-2 — the block describes the portfolio, not the rows returned."""
    portfolio = tool_context.portfolios.get(tool_context.subject)

    outcome = await tool.run({"top_n": 1}, tool_context)
    totals = outcome.data["totals"]

    assert isinstance(totals, dict)
    assert totals["count"] == len(portfolio.holdings())
    assert totals["marketValueDisplay"] == f"${portfolio.total_market_value():,.2f}"
    assert totals["costBasisDisplay"] == f"${portfolio.total_cost_basis():,.2f}"
    assert outcome.data["asOf"] == portfolio.as_of.isoformat()


async def test_the_weights_of_every_position_sum_to_one(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """AC-2 — the GGU-5 invariant, re-asserted at the tool's boundary.

    Within ``WEIGHT_TOLERANCE``, not exactly: a weight is a division, and the
    quotients cannot be expected to add back to one (ADR-E D-4). Asserting
    exact equality here would be asserting something false about arithmetic.
    """
    outcome = await tool.run({}, tool_context)
    positions = held(tool_context)

    assert len(rows(outcome.data["holdings"])) == len(positions)
    total = sum((item.weight for item in positions), ZERO)
    assert abs(total - ONE) <= WEIGHT_TOLERANCE


async def test_every_figure_the_model_sees_is_a_display_string(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """AC-3 — no bare number reaches the model, in a row or in the totals."""
    outcome = await tool.run({}, tool_context)
    totals = outcome.data["totals"]
    assert isinstance(totals, dict)

    for key, value in totals.items():
        assert DISPLAY_KEY.search(key) or key in {"count", "trend"}
        assert isinstance(value, str) or key == "count"
    for row in rows(outcome.data["holdings"]):
        assert all(isinstance(value, str) for value in row.values())
        formatted = {key for key in row if DISPLAY_KEY.search(key)}
        assert formatted == set(row) - NOT_A_FIGURE


async def test_the_same_question_twice_gives_the_same_answer(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """AC-5 — deterministic for a fixed seed and a fixed clock."""
    first = await tool.run({"sort_by": "gainers", "top_n": 2}, tool_context)
    second = await tool.run({"sort_by": "gainers", "top_n": 2}, tool_context)

    assert first.data == second.data


async def test_an_unfiltered_call_asks_for_the_allocation_chart(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """AC-7 — the donut renders the whole portfolio, so it fits this answer."""
    outcome = await tool.run({"top_n": 2}, tool_context)

    assert outcome.render is not None
    assert outcome.render.view == VIEW
    assert outcome.render.options == {"top_n": 2}


async def test_a_filtered_call_asks_for_no_chart(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """AC-7, OD-1 — a whole-portfolio donut would contradict two rows."""
    outcome = await tool.run({"symbols": ["BTC"]}, tool_context)

    assert outcome.render is None
