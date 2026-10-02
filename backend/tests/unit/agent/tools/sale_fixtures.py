"""Shared helpers for the ``simulate_sale`` tests.

Not a test module: it holds the tool fixture, the narrowing helpers and the
constants that the three ``simulate_sale`` test files need, so none of them
repeats another — pylint's duplicate-code check would flag it and a reader
would have to diff them by eye.
"""

import re
from collections.abc import Mapping
from decimal import Decimal

import pytest

from app.agent.tools.simulate_sale import SimulateSaleTool
from app.domain.sale_results import LotConsumption, SaleSimulation
from app.domain.terms import LotTerm
from tests.conftest import FROZEN_NOW

DISPLAY_KEY = re.compile(r"Display$")

#: Payload keys that carry no figure: two cardinalities, a flag, and the
#: tokens and identifiers a widget keys off (spec 0013 §3).
NOT_A_FIGURE = frozenset(
    {
        "symbol",
        "lotMethod",
        "trend",
        "shortTermLots",
        "longTermLots",
        "count",
        "lotId",
        "term",
        "fullySold",
    }
)

#: The one call most of these tests make: 0.75 of the seeded 2.10 BTC, which
#: spans both lots and therefore both terms (spec 0044).
HALF_A_BITCOIN: Mapping[str, object] = {"symbol": "BTC", "quantity": "0.75"}
TEN_THOUSAND_DOLLARS: Mapping[str, object] = {"symbol": "BTC", "amount_usd": "10000"}


@pytest.fixture
def tool() -> SimulateSaleTool:
    """Return the tool under test."""
    return SimulateSaleTool()


def block(payload: object) -> Mapping[str, object]:
    """Narrow one block of a tool payload for the type checker.

    Args:
        payload: The ``summary`` or ``remaining`` entry of a tool outcome.

    Returns:
        The same mapping, typed.
    """
    assert isinstance(payload, dict)
    return payload


def lots(payload: object) -> list[Mapping[str, object]]:
    """Narrow the payload's ``lots`` list for the type checker.

    Args:
        payload: The ``lots`` entry of a tool outcome.

    Returns:
        The same list, typed.
    """
    assert isinstance(payload, list)
    return payload


def free_sale() -> SaleSimulation:
    """Build a sale of a lot that cost nothing — an airdrop being sold.

    The seed has no such position, and one is needed to reach the case where
    a return on cost is undefined (spec 0013 OD-6).
    """
    row = LotConsumption(
        lot_id="lot-air-01",
        acquired_on=FROZEN_NOW.date(),
        term=LotTerm.SHORT,
        held_days=0,  # acquired on the frozen day itself, so short-term agrees
        quantity=Decimal(10),
        cost_basis=Decimal(0),
        proceeds=Decimal(500),
        gain_loss=Decimal(500),
        exhausted=True,
    )
    return SaleSimulation(
        symbol="LINK",
        price=Decimal(50),
        quantity=Decimal(10),
        proceeds=Decimal(500),
        cost_basis=Decimal(0),
        realized_pl=Decimal(500),
        remaining_quantity=Decimal(0),
        remaining_cost_basis=Decimal(0),
        remaining_lots=0,
        consumed=(row,),
    )


__all__ = [
    "DISPLAY_KEY",
    "HALF_A_BITCOIN",
    "NOT_A_FIGURE",
    "TEN_THOUSAND_DOLLARS",
    "block",
    "free_sale",
    "lots",
    "tool",
]
