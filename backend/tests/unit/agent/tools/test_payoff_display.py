"""Spec 0014 — how the payoff payload prints, and what it refuses to print.

``test_payoff`` covers what the answer says; this covers how it reads: the
position value that only a purchase has, the price resolution a sub-dollar
ladder needs, and the promise that no bare number reaches the model.
"""

from typing import Final

from app.agent.contracts import ToolContext
from app.agent.tools.payoff import DISCLOSURE, PayoffTool
from tests.unit.agent.tools.payoff_fixtures import SOL, block, rows, tool

__all__ = ["tool"]

#: A sub-dollar ticker at the finest grid the arguments allow (OD-10).
DOGE: Final[str] = "DOGE"

TOP_LEVEL: Final[frozenset[str]] = frozenset(
    {"asOf", "disclosure", "order", "scenarios", "points"}
)
#: The one value in a point row that is not a figure.
NOT_A_FIGURE: Final[frozenset[str]] = frozenset({"trend"})


async def test_a_purchase_is_worth_more_where_it_profits(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """OD-12 — the buy path keeps the position value, and the two agree."""
    outcome = await tool.run({"symbol": SOL, "size": "40"}, tool_context)

    scenarios = block(outcome.data["scenarios"])
    high = block(scenarios["high"])
    assert high["positionValueDisplay"] == "$7,924.80"
    assert high["profitLossDisplay"] == "+$1,828.80"
    assert block(scenarios["low"])["positionValueDisplay"] == "$4,267.20"


async def test_a_sell_loses_where_a_buy_gains_and_values_no_position(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """OD-6, OD-12 — the mirror curve, with nothing left to value.

    The blocker this replaces: the sell rows carried ``$7,924.80`` of
    "position value" beside a loss of ``$1,828.80``, two figures moving in
    opposite directions in one row, in a payload the model copies verbatim.
    """
    outcome = await tool.run(
        {"symbol": SOL, "size": "40", "side": "sell"}, tool_context
    )

    scenarios = block(outcome.data["scenarios"])
    assert block(scenarios["high"])["profitLossDisplay"] == "-$1,828.80"
    assert block(scenarios["high"])["trend"] == "down"
    assert block(scenarios["low"])["trend"] == "up"
    assert block(outcome.data["order"])["side"] == "sell"
    assert all(
        row["positionValueDisplay"] is None for row in rows(outcome.data["points"])
    )
    assert "no position value" in str(outcome.data["disclosure"])


async def test_a_sub_dollar_ticker_still_gets_a_price_per_point(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """OD-10 — the ladder that used to print one price for twenty-six rows.

    At two decimals this curve rendered ``"$0.13"`` for half its points while
    the profit beside them ran from ``-$0.25`` to ``+$6.36``, and the
    break-even was indistinguishable from a losing row. The precision now
    comes from the grid's own step, so every point is its own price and the
    break-even appears exactly once.
    """
    outcome = await tool.run(
        {"symbol": DOGE, "size": "1000", "range_pct": 5, "steps": 25}, tool_context
    )

    points = rows(outcome.data["points"])
    prices = [row["priceDisplay"] for row in points]
    break_even = block(outcome.data["order"])["breakEvenPriceDisplay"]
    assert len(set(prices)) == len(points) == 51
    assert prices.count(break_even) == 1
    assert (
        break_even == block(block(outcome.data["scenarios"])["entry"])["priceDisplay"]
    )


async def test_every_figure_the_model_sees_is_a_display_string(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-5 — no ``Decimal`` and no float reaches the model, anywhere."""
    outcome = await tool.run({"symbol": SOL, "size": "40"}, tool_context)

    assert set(outcome.data) == TOP_LEVEL
    assert outcome.data["disclosure"] == DISCLOSURE
    assert isinstance(outcome.data["asOf"], str)
    for value in block(outcome.data["order"]).values():
        assert isinstance(value, str)
    scenarios = block(outcome.data["scenarios"])
    for row in [*rows(outcome.data["points"]), *(block(v) for v in scenarios.values())]:
        assert all(isinstance(value, str) for value in row.values())
        formatted = {key for key in row if key.endswith("Display")}
        assert formatted == set(row) - NOT_A_FIGURE
