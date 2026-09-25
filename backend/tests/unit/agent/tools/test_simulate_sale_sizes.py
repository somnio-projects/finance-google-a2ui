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
TEN_THOUSAND_IN_UNITS = "0.15564202"


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
        {"symbol": "BTC", "quantity": TEN_THOUSAND_IN_UNITS}, tool_context
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
    assert summary["priceDisplay"] == "$64,250.00"
    assert summary["proceedsDisplay"] == "$10,000.00"


async def test_a_sub_dollar_price_is_shown_at_the_precision_it_is_quoted_to(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """OD-4 — the hand-check must hold for a genuinely sub-dollar asset.

    ARB is quoted at **$0.8640** and the whole position is 50,625 units, so
    ``price_display`` widens to four places and the proceeds a reader
    multiplies out by hand are exactly the ones shown. This case was dead
    while the portfolio was equities (spec 0025 OD-2 — nothing in it was
    quoted below a dollar) and the crypto universe brings it back with real
    data rather than with a synthetic asset (spec 0044).
    """
    summary = block(
        (await tool.run({"symbol": "ARB", "quantity": "50625"}, tool_context)).data[
            "summary"
        ]
    )

    assert summary["priceDisplay"] == "$0.8640"
    assert summary["quantityDisplay"] == "50625"
    assert summary["proceedsDisplay"] == "$43,740.00"


@pytest.mark.parametrize(
    ("amount", "refused"),
    [("134925.01", True), ("134925.000001", False)],
    ids=["a_cent_over_the_position", "a_hair_under_the_rounding"],
)
async def test_a_dollar_amount_at_the_edge_of_the_position_does_not_guess(
    tool: SimulateSaleTool,
    tool_context: ToolContext,
    amount: str,
    refused: bool,
) -> None:
    """OD-4 — quantizing may round a size **down**, never into an over-sell.

    The whole BTC position is worth exactly $134,925.00. A cent more is
    refused rather than quietly clipped to what is there; a millionth of a
    dollar more rounds down to the position itself and sells all of it. That
    monotonicity holds only while every lot quantity stays inside eight
    decimal places, which the seed's do.
    """
    outcome = await tool.run({"symbol": "BTC", "amount_usd": amount}, tool_context)

    assert (outcome.data.get("error") == "position-too-small") is refused
    if refused:
        assert "summary" not in outcome.data
        return
    assert block(outcome.data["summary"])["quantityDisplay"] == "2.1"


async def test_a_dollar_amount_too_small_to_buy_a_unit_is_rejected(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """OD-4 — an amount that rounds to nothing is not a sale of nothing."""
    with pytest.raises(SaleQuantityError, match="positive number of units"):
        await tool.run({"symbol": "BTC", "amount_usd": "0.0000001"}, tool_context)
