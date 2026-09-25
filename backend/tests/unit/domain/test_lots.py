"""AC-2, AC-5 — lot-level arithmetic is exact and never rounds."""

from decimal import Decimal

from app.domain.portfolio import Portfolio
from tests.unit.domain.conftest import make_lot


def test_lot_market_value_is_quantity_times_price_without_rounding() -> None:
    lot = make_lot(quantity="0.4200", cost_basis="18060.00")
    assert lot.market_value(Decimal("64250.00")) == Decimal("26985.000000")


def test_lot_unrealized_pl_is_market_value_minus_cost_basis() -> None:
    lot = make_lot(quantity="0.4200", cost_basis="18060.00")
    assert lot.unrealized_pl(Decimal("64250.00")) == Decimal("8925.000000")


def test_lot_unrealized_pl_is_negative_for_a_lot_under_water() -> None:
    lot = make_lot(quantity="1.0000", cost_basis="70000.00")
    assert lot.unrealized_pl(Decimal("64250.00")) < 0


def test_seeded_lots_add_up_to_the_holding_market_value(
    portfolio: Portfolio,
) -> None:
    btc = portfolio.holdings()[0]
    price = portfolio.price("BTC")
    lots_value = sum(
        (lot.market_value(price) for lot in portfolio.tax_lots("BTC")), Decimal(0)
    )
    assert lots_value == btc.market_value
