"""Spec 0013 OD-4 — how a sale size is named, and what it resolves to.

Dollars and units must describe the same sale, and the figures in one block
must survive the multiplication a reader does between them. What the tool
refuses is `test_simulate_sale_refusals.py`.
"""

import pytest

from app.agent.contracts import ToolContext
from app.agent.tools.simulate_sale import SimulateSaleTool
from app.domain.errors import SaleQuantityError
from tests.unit.agent.tools.sale_fixtures import (
    TEN_THOUSAND_DOLLARS,
    block,
    tool,
)

__all__ = ["tool"]

#: ``$10,000 / $64,250`` at eight decimal places, worked out by hand. The
#: oracle for both dollar-sized tests; computing it with the production
#: resolver would make them agree with themselves (spec 0013 OD-4).
TEN_THOUSAND_IN_UNITS = "8.30109741"


async def test_dollars_and_units_describe_the_same_sale(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """AC-6 — the two ways of naming a size reach the very same answer.

    The unit figure is the **literal** ``$10,000 / $64,250`` rounded to eight
    places. Deriving it by calling ``units()`` — the thing under test — would
    make the two sides agree by construction and the test unable to fail.
    """
    by_dollars = await tool.run(TEN_THOUSAND_DOLLARS, tool_context)
    by_units = await tool.run(
        {"symbol": "NVDA", "quantity": TEN_THOUSAND_IN_UNITS}, tool_context
    )

    assert by_dollars.data == by_units.data


async def test_dollars_resolve_to_a_quantity_the_reader_can_multiply_back(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """OD-4 — rounding the trade size first leaves no cent to explain.

    Both oracles are literals: the quantity is what a reader gets dividing
    $10,000 by $64,250 at eight places, and the proceeds are what they get
    multiplying that quantity back by the price printed in the same block.
    """
    summary = block(
        (await tool.run(TEN_THOUSAND_DOLLARS, tool_context)).data["summary"]
    )

    assert summary["quantityDisplay"] == TEN_THOUSAND_IN_UNITS
    assert summary["priceDisplay"] == "$1,204.66"
    assert summary["proceedsDisplay"] == "$10,000.00"


async def test_a_sub_dollar_price_is_shown_at_the_precision_it_is_quoted_to(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """OD-4 — the hand-check must hold for the cheapest asset held too.

    XOM is quoted at $34.22 and the position is 130 shares, so the proceeds
    a reader multiplies out by hand must be exactly the ones shown. The
    sub-dollar case this test used to cover no longer exists: the portfolio
    is equities (spec 0025 OD-2) and nothing in it is quoted below a dollar.
    `core/test_display.py` still exercises the widening itself.
    """
    summary = block(
        (await tool.run({"symbol": "XOM", "quantity": "130"}, tool_context)).data[
            "summary"
        ]
    )

    assert summary["priceDisplay"] == "$34.22"
    assert summary["quantityDisplay"] == "130"
    assert summary["proceedsDisplay"] == "$4,448.60"


@pytest.mark.parametrize(
    ("amount", "refused"),
    [("108419.41", True), ("108419.400001", False)],
    ids=["a_cent_over_the_position", "a_hair_under_the_rounding"],
)
async def test_a_dollar_amount_at_the_edge_of_the_position_does_not_guess(
    tool: SimulateSaleTool,
    tool_context: ToolContext,
    amount: str,
    refused: bool,
) -> None:
    """OD-4 — quantizing may round a size **down**, never into an over-sell.

    The whole NVDA position is worth exactly $108,419.40. A cent more is
    refused rather than quietly clipped to what is there; a millionth of a
    dollar more rounds down to the position itself and sells all of it. That
    monotonicity holds only while every lot quantity stays inside eight
    decimal places, which the seed's do.
    """
    outcome = await tool.run({"symbol": "NVDA", "amount_usd": amount}, tool_context)

    assert (outcome.data.get("error") == "position-too-small") is refused
    if refused:
        assert "summary" not in outcome.data
        return
    assert block(outcome.data["summary"])["quantityDisplay"] == "90"


async def test_a_dollar_amount_too_small_to_buy_a_unit_is_rejected(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """OD-4 — an amount that rounds to nothing is not a sale of nothing."""
    with pytest.raises(SaleQuantityError, match="positive number of units"):
        await tool.run({"symbol": "NVDA", "amount_usd": "0.0000001"}, tool_context)
