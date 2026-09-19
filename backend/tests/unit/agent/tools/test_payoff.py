"""Spec 0014 — what the payoff tool answers.

The curve's arithmetic is proven in ``tests/unit/domain/test_payoff.py`` and
the declared arguments in ``test_payoff_arguments``; this file is the payload:
the order block, the scenarios, the formatting invariant, determinism and the
deliberate absence of a chart.
"""

from decimal import Decimal
from typing import Final

from app.agent.contracts import ToolContext
from app.agent.tools.payoff import DISCLOSURE, PayoffTool
from app.core.display import money_display, quantity_display
from app.domain.market import price_of
from app.domain.payoff_pricing import order_quantity
from tests.unit.agent.tools.payoff_fixtures import SOL, block, rows, tool

__all__ = ["tool"]

AMOUNT: Final[Decimal] = Decimal(500)
UNITS: Final[Decimal] = Decimal(40)

#: The one value in a point row that is not a figure.
NOT_A_FIGURE: Final[frozenset[str]] = frozenset({"trend"})


async def test_a_dollar_order_is_sized_at_the_entry_price(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-4 — the model states dollars and copies the units it gets back."""
    entry = price_of(SOL)

    outcome = await tool.run(
        {"symbol": SOL, "size": "500", "size_in": "usd"}, tool_context
    )

    order = block(outcome.data["order"])
    assert order["quantityDisplay"] == quantity_display(
        order_quantity(AMOUNT, entry), trim=True
    )
    assert order["entryPriceDisplay"] == money_display(entry)
    assert order["breakEvenPriceDisplay"] == money_display(entry)
    assert order["notionalDisplay"] == money_display(AMOUNT)


async def test_a_size_in_units_is_priced_as_given(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-4 — the other branch: no division, the size is the quantity."""
    outcome = await tool.run({"symbol": SOL, "size": "40"}, tool_context)

    order = block(outcome.data["order"])
    assert order["quantityDisplay"] == quantity_display(UNITS, trim=True)
    assert order["notionalDisplay"] == money_display(UNITS * price_of(SOL))


async def test_the_scenarios_name_the_ends_of_the_plotted_range(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-2 — the entry scenario makes nothing, and says so in both fields."""
    outcome = await tool.run({"symbol": SOL, "size": "40"}, tool_context)

    points = rows(outcome.data["points"])
    scenarios = block(outcome.data["scenarios"])
    assert scenarios["low"] == points[0]
    assert scenarios["high"] == points[-1]
    entry = block(scenarios["entry"])
    assert entry["profitLossDisplay"] == "$0.00"
    assert entry["trend"] == "flat"


async def test_a_sell_loses_where_a_buy_gains(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """OD-6 — the mirror curve, stated in the strings the model copies."""
    outcome = await tool.run(
        {"symbol": SOL, "size": "40", "side": "sell"}, tool_context
    )

    scenarios = block(outcome.data["scenarios"])
    assert block(scenarios["high"])["trend"] == "down"
    assert block(scenarios["low"])["trend"] == "up"
    assert block(outcome.data["order"])["side"] == "sell"


async def test_every_figure_the_model_sees_is_a_display_string(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-5 — no ``Decimal`` and no float reaches the model, anywhere."""
    outcome = await tool.run({"symbol": SOL, "size": "40"}, tool_context)

    assert outcome.data["disclosure"] == DISCLOSURE
    for value in block(outcome.data["order"]).values():
        assert isinstance(value, str)
    for row in rows(outcome.data["points"]):
        assert all(isinstance(value, str) for value in row.values())
        formatted = {key for key in row if key.endswith("Display")}
        assert formatted == set(row) - NOT_A_FIGURE


async def test_the_same_order_twice_gives_the_same_answer(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-6 — deterministic for a fixed seed, a fixed clock and fixed args."""
    order = {"symbol": SOL, "size": "1.5", "range_pct": 15, "steps": 3}

    first = await tool.run(order, tool_context)
    second = await tool.run(order, tool_context)

    assert first.data == second.data


async def test_the_curve_is_bounded_by_the_step_limit(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-6 — the biggest curve any argument can ask for is 51 points."""
    outcome = await tool.run({"symbol": SOL, "size": "40", "steps": 25}, tool_context)

    assert len(rows(outcome.data["points"])) == 51


async def test_it_asks_for_no_chart_because_none_of_them_is_a_payoff_curve(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-8, OD-7 — a donut under a P/L curve would be confidently wrong."""
    outcome = await tool.run({"symbol": SOL, "size": "40"}, tool_context)

    assert outcome.render is None
