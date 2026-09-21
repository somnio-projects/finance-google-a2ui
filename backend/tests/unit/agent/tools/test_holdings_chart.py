"""Spec 0011 AC-7 / OD-1 — when the answer still fits the allocation chart.

``holdings.allocation.v1`` draws the whole portfolio, ordered by value. Two
different arguments can make the answer disagree with it, and both are tested
here because they are the same mistake: a filter, and an order by return.
"""

from app.agent.contracts import ToolContext
from app.agent.tools.holdings_query import MAX_TOP_N, HoldingsSummaryArguments
from app.agent.tools.holdings_summary import VIEW, HoldingsSummaryTool
from tests.unit.agent.tools.holdings_fixtures import held
from tests.unit.agent.tools.holdings_fixtures import tool as tool


async def test_a_default_call_asks_for_the_allocation_chart(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """AC-7 — the whole portfolio, largest first: what the donut draws."""
    outcome = await tool.run({}, tool_context)

    assert outcome.render is not None
    assert outcome.render.view == VIEW
    assert outcome.render.options == {"top_n": len(await held(tool_context))}


async def test_a_filtered_call_asks_for_no_chart(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """AC-7, OD-1 — a whole-portfolio donut would contradict two rows."""
    outcome = await tool.run({"symbols": ["BTC"]}, tool_context)

    assert outcome.render is None


async def test_an_order_by_return_asks_for_no_chart(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """AC-7, OD-1 — the donut always sorts by value.

    The regression this guards: "here are your two worst losers" under a
    chart of the two **largest** positions. The filter hole and this one are
    the same hole, one argument apart.
    """
    outcome = await tool.run({"sort_by": "losers", "top_n": 2}, tool_context)

    assert outcome.render is None


def test_the_chart_is_never_asked_for_more_rows_than_it_declares() -> None:
    """The projection bounds ``top_n`` at 20; the portfolio is not bounded.

    Unreachable from today's five-symbol seed, which is why it is asserted at
    the seam rather than through a portfolio nobody can build yet.
    """
    options = HoldingsSummaryArguments()

    assert options.chart_options(MAX_TOP_N + 5) == {"top_n": MAX_TOP_N}
    assert options.chart_options(0) is None
