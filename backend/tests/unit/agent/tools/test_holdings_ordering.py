"""Spec 0011 AC-4 — which positions the holdings tool answers with, and in what order.

Ordering is asserted against the **domain**, never against numbers parsed back
out of formatted strings: a test that re-parses a display string proves the
formatter and the test agree, not that the answer is right.
"""

import pytest
from pydantic import ValidationError

from app.agent.contracts import ToolContext
from app.agent.tools.holdings_query import SORTERS
from app.agent.tools.holdings_summary import HoldingsSummaryTool
from app.domain.returns import return_on_cost
from tests.unit.agent.tools.holdings_fixtures import held, rows, symbols_of, tool

__all__ = ["tool"]


@pytest.mark.parametrize("sort_by", sorted(SORTERS), ids=sorted(SORTERS))
async def test_each_order_matches_what_the_domain_ranks(
    tool: HoldingsSummaryTool, tool_context: ToolContext, sort_by: str
) -> None:
    outcome = await tool.run({"sort_by": sort_by}, tool_context)
    expected = SORTERS[sort_by](held(tool_context))

    assert symbols_of(outcome.data["holdings"]) == [item.symbol for item in expected]


async def test_weight_and_value_are_the_same_order(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """OD-4 — aliases by construction; pinned so nobody 'fixes' one of them."""
    by_weight = await tool.run({"sort_by": "weight"}, tool_context)
    by_value = await tool.run({"sort_by": "value"}, tool_context)

    assert by_weight.data["holdings"] == by_value.data["holdings"]


async def test_gainers_and_losers_are_opposite_orders(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """OD-5 — ranked by return on cost, best first and worst first."""
    ranked = sorted(
        held(tool_context),
        key=lambda item: return_on_cost(item.unrealized_pl, item.cost_basis) or 0,
        reverse=True,
    )
    gainers = await tool.run({"sort_by": "gainers"}, tool_context)
    losers = await tool.run({"sort_by": "losers"}, tool_context)

    ordered = symbols_of(gainers.data["holdings"])
    assert ordered == [item.symbol for item in ranked]
    assert symbols_of(losers.data["holdings"]) == ordered[::-1]


@pytest.mark.parametrize(
    "asked", [["btc"], [" BTC "], ["BTC"]], ids=["lowercase", "padded", "canonical"]
)
async def test_the_symbols_filter_normalises_what_it_was_asked_for(
    tool: HoldingsSummaryTool, tool_context: ToolContext, asked: list[str]
) -> None:
    """One ask, however the model spelled it (spec 0003 AC-4)."""
    outcome = await tool.run({"symbols": asked}, tool_context)

    assert symbols_of(outcome.data["holdings"]) == ["BTC"]


async def test_an_unknown_symbol_matches_nothing_rather_than_failing(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """A ticker the portfolio does not hold is an empty answer, not an error."""
    outcome = await tool.run({"symbols": ["ZZZ"]}, tool_context)
    totals = outcome.data["totals"]

    assert rows(outcome.data["holdings"]) == []
    assert isinstance(totals, dict)
    assert totals["count"] == len(held(tool_context))


async def test_top_n_cuts_after_sorting_not_before(
    tool: HoldingsSummaryTool, tool_context: ToolContext
) -> None:
    """The first row of a trimmed call is the first row of the full one."""
    full = await tool.run({"sort_by": "losers"}, tool_context)
    trimmed = await tool.run({"sort_by": "losers", "top_n": 1}, tool_context)

    assert rows(trimmed.data["holdings"]) == rows(full.data["holdings"])[:1]


@pytest.mark.parametrize(
    "arguments",
    [
        {"top_n": 0},
        {"top_n": 99},
        {"unknown": 1},
        {"top_n": "two"},
        {"sort_by": "alphabetical"},
        {"symbols": [f"S{index}" for index in range(21)]},
    ],
    ids=[
        "below_bound",
        "above_bound",
        "undeclared_option",
        "wrong_type",
        "unknown_order",
        "too_many_symbols",
    ],
)
async def test_run_rejects_arguments_the_schema_does_not_declare(
    tool: HoldingsSummaryTool,
    tool_context: ToolContext,
    arguments: dict[str, object],
) -> None:
    """OD-7 — rejected, never coerced into the default."""
    with pytest.raises(ValidationError, match=r"top_n|unknown|sort_by|symbols"):
        await tool.run(arguments, tool_context)
