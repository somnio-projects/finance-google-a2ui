"""Spec 0013 — the arguments and the asks ``simulate_sale`` turns down.

The other half of `test_simulate_sale_sizes.py`. Two kinds of refusal live
here and they are deliberately different: an **argument** the model got wrong
raises out of pydantic, while an **ask** the portfolio cannot satisfy comes
back as a structured answer the model can read out (OD-3).
"""

import pytest
from pydantic import ValidationError

from app.agent.contracts import ToolContext
from app.agent.tools.simulate_sale import SimulateSaleTool
from app.domain.errors import SaleQuantityError
from tests.unit.agent.tools.sale_fixtures import tool

__all__ = ["tool"]


async def test_selling_more_than_is_held_answers_instead_of_failing(
    tool: SimulateSaleTool, tool_context: ToolContext
) -> None:
    """AC-6, OD-3 — the shortfall is the useful part, so it is in the payload.

    A raising tool would reach the model as ``{"error": "tool-failed"}`` and
    the one number that makes the answer helpful would be gone.

    The absent render intent is spec 0015 AC-13's other half: there are no
    lots to draw, and a tax-lot table under "you hold fewer units than that"
    is the contradiction spec 0011 OD-1 named.
    """
    outcome = await tool.run({"symbol": "NVDA", "quantity": "150"}, tool_context)

    assert outcome.data["error"] == "position-too-small"
    assert outcome.data["requestedDisplay"] == "150"
    assert outcome.data["heldDisplay"] == "90"
    assert "summary" not in outcome.data
    assert outcome.render is None


@pytest.mark.parametrize(
    "arguments",
    [
        {"symbol": "NVDA"},
        {"symbol": "NVDA", "quantity": "75", "amount_usd": "10000"},
    ],
    ids=["neither_size_given", "both_sizes_given"],
)
async def test_a_sale_takes_exactly_one_size(
    tool: SimulateSaleTool,
    tool_context: ToolContext,
    arguments: dict[str, str],
) -> None:
    """AC-6 — guessing which one was meant is the fallback OD-3 rejects."""
    with pytest.raises(SaleQuantityError, match="exactly one of"):
        await tool.run(arguments, tool_context)


@pytest.mark.parametrize(
    "arguments",
    [
        {"symbol": "NVDA", "quantity": "half"},
        {"symbol": "NVDA", "quantity": "-0.5"},
        {"symbol": "NVDA", "quantity": "1e5"},
        {"symbol": "NVDA", "quantity": "0.123456789"},
        {"symbol": "B", "quantity": "75"},
        {"symbol": "b$", "quantity": "75"},
        {"symbol": "NVDA", "quantity": "75", "lot_method": "AVERAGE"},
        {"symbol": "NVDA", "quantity": "75", "after_tax": True},
    ],
    ids=[
        "a_word_instead_of_a_number",
        "a_negative_size",
        "scientific_notation",
        "more_precision_than_units_have",
        "a_ticker_too_short_to_exist",
        "a_ticker_that_is_not_a_ticker",
        "a_lot_method_nobody_declared",
        "an_argument_nobody_declared",
    ],
)
async def test_an_undeclared_or_out_of_range_argument_is_rejected(
    tool: SimulateSaleTool,
    tool_context: ToolContext,
    arguments: dict[str, object],
) -> None:
    """AC-6 — ADR-K D-3: declared and bounded, or rejected. Never coerced."""
    with pytest.raises(ValidationError):
        await tool.run(arguments, tool_context)
