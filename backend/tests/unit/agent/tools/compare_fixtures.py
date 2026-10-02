"""Shared helpers for the ``compare_lot_methods`` tests (spec 0052).

Not a test module: it holds the tool fixture and the two calls the suites
share, so neither repeats the other — pylint's duplicate-code check would
flag it and a reader would have to diff them by eye.
"""

from collections.abc import Mapping

import pytest

from app.agent.tools.compare_methods import CompareLotMethodsTool
from app.presentation.views import LOADED

#: Importing the views package is what runs every projection's ``register``,
#: and ``test_compare_render`` resolves the tool's view id through the **real**
#: registry. Without this the registry is empty and those tests pass only when
#: some other module happened to import it first — which is what
#: ``test_simulate_sale_render.py`` relies on today, and why running it alone
#: fails. Named rather than discarded so the import is not an unused one.
PROJECTIONS: tuple[str, ...] = LOADED

#: The call the demo's chip makes: $20k of the seeded 2.10 BTC, which spans
#: both lots and therefore makes the methods disagree.
TWENTY_THOUSAND: Mapping[str, object] = {"symbol": "BTC", "amount_usd": "20000"}

#: The same sale named in units, for the tests that assert on the size.
THREE_QUARTERS: Mapping[str, object] = {"symbol": "BTC", "quantity": "0.75"}


@pytest.fixture
def tool() -> CompareLotMethodsTool:
    """Return the tool under test."""
    return CompareLotMethodsTool()


def columns(payload: object) -> list[Mapping[str, object]]:
    """Narrow the payload's ``columns`` list for the type checker.

    Args:
        payload: The ``columns`` entry of a tool outcome.

    Returns:
        The same list, typed.
    """
    assert isinstance(payload, list)
    return payload


def subject(payload: object) -> Mapping[str, object]:
    """Narrow the payload's ``subject`` block for the type checker.

    Args:
        payload: The ``subject`` entry of a tool outcome.

    Returns:
        The same mapping, typed.
    """
    assert isinstance(payload, dict)
    return payload


__all__ = [
    "PROJECTIONS",
    "THREE_QUARTERS",
    "TWENTY_THOUSAND",
    "columns",
    "subject",
    "tool",
]
