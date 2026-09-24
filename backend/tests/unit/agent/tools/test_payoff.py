"""Spec 0014 — what the payoff tool answers.

The curve's arithmetic is proven in ``tests/unit/domain/test_payoff.py`` and
the declared arguments in ``test_payoff_arguments``; this file is the payload:
the order block, the scenarios, the formatting invariant, determinism and the
deliberate absence of a chart.

The expected figures are the hand-computed ones from spec 0014 §3, written out
as literals. Recomputing them here by calling the production helpers would be
a test that agrees with the code whatever the code says.
"""

from typing import Final

from app.agent.contracts import ToolContext
from app.agent.tools.payoff import PayoffTool
from tests.unit.agent.tools.payoff_fixtures import VOO, block, rows, tool

__all__ = ["tool"]

#: Spec 0014 §3, for $500 of VOO at the seeded price of $152.40.
QUANTITY_FOR_500: Final[str] = "0.9469697"
ENTRY_DISPLAY: Final[str] = "$528.00"


async def test_a_dollar_order_is_sized_at_the_entry_price(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-4 — the model states dollars and copies the units it gets back."""
    outcome = await tool.run(
        {"symbol": VOO, "size": "500", "size_in": "usd"}, tool_context
    )

    order = block(outcome.data["order"])
    assert order["quantityDisplay"] == QUANTITY_FOR_500
    assert order["entryPriceDisplay"] == ENTRY_DISPLAY
    assert order["breakEvenPriceDisplay"] == ENTRY_DISPLAY
    assert order["notionalDisplay"] == "$500.00"


async def test_a_size_in_units_is_priced_as_given(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-4 — the other branch: no division, the size is the quantity."""
    outcome = await tool.run({"symbol": VOO, "size": "40"}, tool_context)

    order = block(outcome.data["order"])
    assert order["quantityDisplay"] == "40"
    assert order["entryPriceDisplay"] == ENTRY_DISPLAY
    assert order["notionalDisplay"] == "$21,120.00"


async def test_the_scenarios_name_the_ends_of_the_plotted_range(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-2 — the entry scenario makes nothing, and says so in both fields."""
    outcome = await tool.run({"symbol": VOO, "size": "40"}, tool_context)

    points = rows(outcome.data["points"])
    scenarios = block(outcome.data["scenarios"])
    assert scenarios["low"] == points[0]
    assert scenarios["high"] == points[-1]
    entry = block(scenarios["entry"])
    assert entry["priceDisplay"] == ENTRY_DISPLAY
    assert entry["profitLossDisplay"] == "$0.00"
    assert entry["trend"] == "flat"


async def test_the_same_order_twice_gives_the_same_answer(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-6 — deterministic for a fixed seed, a fixed clock and fixed args."""
    order = {"symbol": VOO, "size": "1.5", "range_pct": 15, "steps": 3}

    first = await tool.run(order, tool_context)
    second = await tool.run(order, tool_context)

    assert first.data == second.data


async def test_the_curve_is_bounded_by_the_step_limit(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-6 — the biggest curve any argument can ask for is 51 points."""
    outcome = await tool.run({"symbol": VOO, "size": "40", "steps": 25}, tool_context)

    assert len(rows(outcome.data["points"])) == 51


async def test_it_asks_for_no_chart_because_none_of_them_is_a_payoff_curve(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-8, OD-7 — a donut under a P/L curve would be confidently wrong."""
    outcome = await tool.run({"symbol": VOO, "size": "40"}, tool_context)

    assert outcome.render is None
