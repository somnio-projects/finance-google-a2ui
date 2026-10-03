"""GGU-149 AC-5/AC-6 — "build a 10k order in btc" is sized to $10k.

Split from ``test_draft_order`` for the file budget; same fixtures.
"""

import pytest

from app.agent.contracts import ToolContext
from app.agent.tools.draft_order import DraftOrderTool
from tests.unit.agent.tools.payoff_fixtures import block


@pytest.fixture
def tool() -> DraftOrderTool:
    """Return the tool under test."""
    return DraftOrderTool()


async def test_a_ten_thousand_dollar_btc_order_is_sized_to_ten_thousand(
    tool: DraftOrderTool, tool_context: ToolContext
) -> None:
    """GGU-149 AC-5/AC-6 — "build a 10k order in btc".

    The largest BTC step at or below $10,000 at $64,250.00 is 0.15 BTC
    ($9,637.50; 0.16 would be $10,280.00), and the words the model copies and
    the surface it renders carry the same legs, so card and prose agree.
    """
    outcome = await tool.run({"amount": "10000", "basket": "bitcoin"}, tool_context)

    assert outcome.data["legs"] == "BTC:0.15"
    assert block(outcome.data["impact"])["totalDisplay"] == "$9,637.50"
    assert outcome.render is not None
    assert outcome.render.options["legs"] == outcome.data["legs"]
