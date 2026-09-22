"""Spec 0011 — what the holdings tool answers.

Which positions, in which order, is ``test_holdings_ordering``; this file is
the payload: the totals, the formatting invariant, determinism and the render
intent.
"""

import re

from app.agent.contracts import ToolContext
from app.agent.tools.holdings_summary import HoldingsSummaryTool
from app.core.display import money_display, percentage_display
from app.core.signed_display import signed_money_display
from app.core.trend import trend_of
from app.domain.invariants import WEIGHT_TOLERANCE
from app.domain.money import ONE, ZERO
from app.domain.returns import return_on_cost
from tests.unit.agent.tools.holdings_fixtures import held, rows
from tests.unit.agent.tools.holdings_fixtures import tool as tool

DISPLAY_KEY = re.compile(r"Display$")
NOT_A_FIGURE = frozenset({"symbol", "name", "trend"})
#: The one documented nullable figure (spec 0011 OD-2).
NULLABLE = "unrealizedPlPctDisplay"


async def test_it_describes_itself_for_the_model_to_choose_by(
    tool: HoldingsSummaryTool,
) -> None:
    """AC-1 — the description and the schema are what the model picks from."""
    assert tool.name == "get_holdings_summary"
    assert "gainers" in tool.description
    properties = tool.parameters["properties"]
    assert isinstance(properties, dict)
    assert set(properties) == {"sort_by", "symbols", "top_n", "group_by"}
    assert tool.parameters["additionalProperties"] is False


async def test_the_totals_agree_with_the_domain(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """AC-2 — every figure in the block, against the domain that computed it.

    Asserted on a trimmed call on purpose: the block describes the
    **portfolio**, not the rows returned.
    """
    portfolio = await tool_context.portfolios.get(tool_context.owner)
    profit = portfolio.total_unrealized_pl()
    ratio = return_on_cost(profit, portfolio.total_cost_basis())
    assert ratio is not None

    outcome = await tool.run({"top_n": 1}, tool_context)
    totals = outcome.data["totals"]

    assert isinstance(totals, dict)
    assert totals["count"] == len(portfolio.holdings())
    assert totals["marketValueDisplay"] == money_display(portfolio.total_market_value())
    assert totals["costBasisDisplay"] == money_display(portfolio.total_cost_basis())
    assert totals["unrealizedPlDisplay"] == signed_money_display(profit)
    assert totals[NULLABLE] == percentage_display(ratio)
    assert totals["trend"] == trend_of(profit)
    assert outcome.data["asOf"] == portfolio.as_of.isoformat()


async def test_every_row_carries_the_figures_the_domain_computed(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """AC-2 — the payload's own numbers, not the domain's, compared per row."""
    outcome = await tool.run({}, tool_context)
    by_symbol = {item.symbol: item for item in await held(tool_context)}

    for row in rows(outcome.data["holdings"]):
        symbol = row["symbol"]
        assert isinstance(symbol, str)
        holding = by_symbol[symbol]
        assert row["weightDisplay"] == percentage_display(holding.weight)
        assert row["marketValueDisplay"] == money_display(holding.market_value)
        assert row["unrealizedPlDisplay"] == signed_money_display(holding.unrealized_pl)


async def test_the_weights_of_every_position_sum_to_one(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """AC-2 — the GGU-5 invariant, within ``WEIGHT_TOLERANCE``.

    Not exactly: a weight is a division, and the quotients cannot be expected
    to add back to one (ADR-E D-4). Asserting exact equality here would be
    asserting something false about arithmetic.
    """
    outcome = await tool.run({}, tool_context)
    positions = await held(tool_context)

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
        assert isinstance(value, str) or key == "count" or key == NULLABLE
    for row in rows(outcome.data["holdings"]):
        for key, value in row.items():
            assert isinstance(value, str) or key == NULLABLE
        formatted = {key for key in row if DISPLAY_KEY.search(key)}
        assert formatted == set(row) - NOT_A_FIGURE


async def test_the_same_question_twice_gives_the_same_answer(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """AC-5 — deterministic for a fixed seed and a fixed clock."""
    first = await tool.run({"sort_by": "gainers", "top_n": 2}, tool_context)
    second = await tool.run({"sort_by": "gainers", "top_n": 2}, tool_context)

    assert first.data == second.data
