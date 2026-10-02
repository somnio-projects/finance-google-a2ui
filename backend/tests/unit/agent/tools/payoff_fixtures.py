"""Shared helpers for the payoff tool's tests.

Not a test module: it holds the fixture and the two narrowing helpers that
``test_payoff`` and ``test_payoff_arguments`` both need. Extracted so neither
file repeats them, which pylint's duplicate-code check would flag and a reader
would have to diff by eye.
"""

from collections.abc import Mapping
from typing import Final

import pytest

from app.agent.tools.payoff import PayoffTool

#: The seeded symbol with an order story behind it (spec 0003 seed data).
SOL: Final[str] = "SOL"


@pytest.fixture
def tool() -> PayoffTool:
    """Return the tool under test."""
    return PayoffTool()


def block(payload: object) -> Mapping[str, object]:
    """Narrow a nested payload block for the type checker.

    Args:
        payload: One entry of a tool outcome.

    Returns:
        The same mapping, typed.
    """
    assert isinstance(payload, Mapping)
    return payload


def rows(payload: object) -> list[Mapping[str, object]]:
    """Narrow the curve's point list for the type checker.

    Args:
        payload: The ``points`` entry of a tool outcome.

    Returns:
        The same list, typed.
    """
    assert isinstance(payload, list)
    return [block(row) for row in payload]


__all__ = ["SOL", "block", "rows", "tool"]
