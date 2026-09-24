"""AC-2 — the invariants are exact and ``validate`` can actually fail.

A passing seed proves nothing unless a hand-built violation is rejected, so
every check here builds a portfolio that breaks exactly one rule and asserts
the message names the offending holding.
"""

from decimal import Decimal

import pytest

from app.domain.errors import PortfolioInvariantError
from app.domain.invariants import (
    WEIGHT_TOLERANCE,
    validate_holding,
    validate_lot_dates,
    validate_weights,
)
from app.domain.lots import TaxLot
from tests.conftest import FROZEN_NOW
from tests.unit.domain.conftest import make_holding, make_lot

PRICE = Decimal("64250.00")


def test_validate_holding_accepts_a_consistent_holding() -> None:
    validate_holding(make_holding(), lots=[make_lot()], price=PRICE)


def test_validate_holding_quantity_mismatch_names_the_holding() -> None:
    holding = make_holding(symbol="AAPL", quantity="2.0000", market_value="128500.0000")
    with pytest.raises(
        PortfolioInvariantError, match=r"holding AAPL: quantity must equal the sum"
    ):
        validate_holding(holding, lots=[make_lot(symbol="AAPL")], price=PRICE)


def test_validate_holding_cost_basis_mismatch_names_the_holding() -> None:
    holding = make_holding(symbol="VOO", cost_basis="39999.99")
    with pytest.raises(
        PortfolioInvariantError, match=r"holding VOO: cost_basis must equal the sum"
    ):
        validate_holding(holding, lots=[make_lot(symbol="VOO")], price=PRICE)


def test_validate_holding_market_value_mismatch_names_the_holding() -> None:
    holding = make_holding(symbol="XOM", market_value="64250.01")
    with pytest.raises(
        PortfolioInvariantError,
        match=r"holding XOM: market_value must equal quantity times price",
    ):
        validate_holding(holding, lots=[make_lot(symbol="XOM")], price=PRICE)


def test_validate_holding_tolerates_no_epsilon_on_market_value() -> None:
    holding = make_holding(market_value="64250.0001")
    with pytest.raises(PortfolioInvariantError, match=r"expected 64250\.0000"):
        validate_holding(holding, lots=[make_lot()], price=PRICE)


def test_validate_lot_dates_accepts_lots_acquired_before_as_of() -> None:
    validate_lot_dates([make_lot(days_before=1)], as_of=FROZEN_NOW.date())


def test_validate_lot_dates_rejects_a_lot_from_the_future() -> None:
    future: TaxLot = make_lot(lot_id="lot-btc-99", days_before=-1)
    with pytest.raises(
        PortfolioInvariantError, match=r"holding NVDA: lot lot-btc-99 was acquired"
    ):
        validate_lot_dates([future], as_of=FROZEN_NOW.date())


def test_validate_weights_inside_tolerance_is_accepted() -> None:
    validate_weights(
        [
            make_holding(symbol="NVDA", weight="0.5"),
            make_holding(symbol="AAPL", weight=str(Decimal("0.5") - WEIGHT_TOLERANCE)),
        ]
    )


def test_validate_weights_outside_tolerance_is_rejected() -> None:
    with pytest.raises(
        PortfolioInvariantError, match=r"weights must sum to 1 within 0\.0001"
    ):
        validate_weights([make_holding(weight="0.75")])
