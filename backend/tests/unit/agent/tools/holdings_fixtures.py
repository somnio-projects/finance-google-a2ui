"""Shared helpers for the holdings tool's tests.

Not a test module: it holds the two narrowing helpers and the fixture that
``test_holdings_summary`` and ``test_holdings_ordering`` both need. Extracted
so neither test file repeats them, which pylint's duplicate-code check would
flag and a reader would have to diff by eye.
"""

import pytest

from app.agent.contracts import ToolContext
from app.agent.tools.holdings_summary import HoldingsSummaryTool
from app.domain.holdings import Holding


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


def held(context: ToolContext) -> list[Holding]:
    """Return the seeded positions straight from the domain."""
    return context.portfolios.get(context.subject).holdings()


__all__ = ["held", "rows", "symbols_of", "tool"]
