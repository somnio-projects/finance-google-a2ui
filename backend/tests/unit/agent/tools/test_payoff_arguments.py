"""Spec 0014 — what the payoff tool refuses to answer.

Every rejection here is a rejection, never a quiet fall back to a default
(AC-7, OD-5): the model gets a tool error it can retry with a legal value,
which is strictly more information than a confidently wrong curve.
"""

from collections.abc import Mapping

import pytest
from pydantic import ValidationError

from app.agent.contracts import ToolContext
from app.agent.tools.payoff import PayoffTool
from app.core.model import ToolSpec
from app.domain.errors import SymbolNotFoundError
from tests.unit.agent.tools.payoff_fixtures import SOL, tool

__all__ = ["tool"]


async def test_it_describes_itself_for_the_model_to_choose_by(
    tool: PayoffTool,
) -> None:
    """AC-1 — the description and the schema are what the model picks from."""
    assert tool.name == "payoff"
    properties = tool.parameters["properties"]
    assert isinstance(properties, dict)
    assert set(properties) == {
        "symbol",
        "size",
        "size_in",
        "side",
        "range_pct",
        "steps",
    }
    assert tool.parameters["additionalProperties"] is False


async def test_the_description_fits_what_the_registry_publishes(
    tool: PayoffTool,
) -> None:
    """AC-1 — ``ToolSpec`` bounds it at 512 characters; over that never ships."""
    spec = ToolSpec(
        name=tool.name, description=tool.description, parameters=tool.parameters
    )

    assert spec.description == tool.description


async def test_an_unknown_ticker_is_refused_not_guessed(
    tool: PayoffTool, tool_context: ToolContext
) -> None:
    """AC-7 — the model gets a recoverable error, not a price for nothing."""
    with pytest.raises(SymbolNotFoundError, match="not in the market reference"):
        await tool.run({"symbol": "XYZ", "size": "1"}, tool_context)


@pytest.mark.parametrize(
    ("arguments", "complaint"),
    [
        ({"symbol": SOL, "size": "0"}, "greater than zero"),
        ({"symbol": SOL, "size": "-5"}, "should match pattern"),
        ({"symbol": SOL, "size": "a lot"}, "should match pattern"),
        ({"symbol": SOL}, "Field required"),
        ({"symbol": SOL, "size": "1", "steps": 26}, "less than or equal to 25"),
        ({"symbol": SOL, "size": "1", "range_pct": 99}, "less than or equal to 90"),
        ({"symbol": SOL, "size": "1", "side": "hold"}, "'buy' or 'sell'"),
        (
            {"symbol": SOL, "size": "1", "amount_usd": "500"},
            "Extra inputs are not permitted",
        ),
    ],
    ids=[
        "zero_size",
        "negative_size",
        "unparseable_size",
        "no_size_at_all",
        "too_many_steps",
        "range_beyond_the_bound",
        "a_side_that_is_not_a_side",
        "an_argument_nobody_declared",
    ],
)
async def test_a_rejected_argument_is_never_a_default(
    tool: PayoffTool,
    tool_context: ToolContext,
    arguments: Mapping[str, object],
    complaint: str,
) -> None:
    """AC-7, OD-5 — out of range is an error the model can retry, not a guess."""
    with pytest.raises(ValidationError, match=complaint):
        await tool.run(arguments, tool_context)
