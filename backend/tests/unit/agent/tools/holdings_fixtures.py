"""Shared helpers for the holdings tool's tests.

Not a test module: it holds the two narrowing helpers and the fixture that
``test_holdings_summary`` and ``test_holdings_ordering`` both need. Extracted
so neither test file repeats them, which pylint's duplicate-code check would
flag and a reader would have to diff by eye.
"""

from decimal import Decimal

import pytest

from app.agent.contracts import ToolContext
from app.agent.tools.holdings_summary import HoldingsSummaryTool
from app.domain.holdings import Holding

#: A position the seeded portfolio does not contain: acquired at no cost, so
#: it has no return on cost and every path that divides by one has to say so
#: rather than invent a number (spec 0011 OD-2, OD-5).
AIRDROP = Holding(
    symbol="FREE",
    name="Airdropped token",
    quantity=Decimal("100"),
    price=Decimal("5"),
    market_value=Decimal("500"),
    cost_basis=Decimal(0),
    unrealized_pl=Decimal("500"),
    weight=Decimal("0.03"),
)


@pytest.fixture
def tool() -> HoldingsSummaryTool:
    """Return the tool under test."""
    return HoldingsSummaryTool()


def rows(payload: object) -> list[dict[str, object]]:
    """Narrow the payload's holdings list for the type checker.

    Args:
        payload: The ``holdings`` entry of a tool outcome.

    Returns:
        The same list, typed.
    """
    assert isinstance(payload, list)
    return payload


def symbols_of(payload: object) -> list[object]:
    """Return the ticker of every row, in payload order."""
    return [row["symbol"] for row in rows(payload)]


async def held(context: ToolContext) -> list[Holding]:
    """Return the seeded positions straight from the domain."""
    return (await context.portfolios.get(context.owner)).holdings()


__all__ = ["AIRDROP", "held", "rows", "symbols_of", "tool"]
