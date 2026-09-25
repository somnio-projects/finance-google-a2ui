"""Fixtures for the portfolio domain suite (spec 0003).

Everything is built at the frozen ``as_of`` the rest of the unit suite uses,
so a lot sitting on the 1-year boundary stays where the tests put it.
"""

from datetime import timedelta
from decimal import Decimal

import pytest

from app.domain.holdings import Holding
from app.domain.lots import TaxLot
from app.domain.portfolio import Portfolio
from app.domain.seed import seed_portfolio
from tests.conftest import FROZEN_NOW


@pytest.fixture
def portfolio() -> Portfolio:
    """The curated seed, built at the frozen ``as_of``."""
    return seed_portfolio(as_of=FROZEN_NOW)


def make_lot(
    *,
    lot_id: str = "lot-test-01",
    symbol: str = "BTC",
    days_before: int = 30,
    quantity: str = "1.0000",
    cost_basis: str = "40000.00",
) -> TaxLot:
    """Build one hand-made lot relative to the frozen ``as_of``."""
    return TaxLot(
        lot_id=lot_id,
        symbol=symbol,
        acquired_on=(FROZEN_NOW - timedelta(days=days_before)).date(),
        quantity=Decimal(quantity),
        cost_basis=Decimal(cost_basis),
    )


def make_holding(
    *,
    symbol: str = "BTC",
    quantity: str = "1.0000",
    price: str = "64250.00",
    market_value: str = "64250.0000",
    cost_basis: str = "40000.00",
    weight: str = "1",
) -> Holding:
    """Build one hand-made holding, by default invariant-clean."""
    return Holding(
        symbol=symbol,
        name="Test Asset",
        quantity=Decimal(quantity),
        price=Decimal(price),
        market_value=Decimal(market_value),
        cost_basis=Decimal(cost_basis),
        unrealized_pl=Decimal(market_value) - Decimal(cost_basis),
        weight=Decimal(weight),
    )


def make_portfolio(*lots: TaxLot) -> Portfolio:
    """Wrap hand-made lots in a portfolio at the frozen ``as_of``.

    Positions and ledger are empty on purpose: a sale reads lots and a price,
    and a test that also handed it an aggregate could pass while the walk
    ignored the lots entirely (spec 0013).
    """
    return Portfolio(as_of=FROZEN_NOW, positions=(), lots=lots, ledger=())
