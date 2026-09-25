"""Spec 0013 — where a simulated sale stops, and what it refuses.

The other half of `test_sales.py`: the leftover position, the two rejections,
and the proof that the comparator's own closure check can fail.
"""

from decimal import Decimal

import pytest

from app.domain.errors import (
    PositionTooSmallError,
    SaleQuantityError,
    SymbolNotFoundError,
)
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio
from app.domain.sale_results import LotConsumption, SaleSimulation
from app.domain.sales import simulate_sale
from app.domain.terms import LotTerm
from tests.conftest import FROZEN_NOW
from tests.unit.domain.conftest import make_portfolio


def test_what_is_left_is_what_was_not_sold(portfolio: Portfolio) -> None:
    """AC-6 — the leftover position, and nothing negative anywhere."""
    lots = portfolio.tax_lots("BTC")
    held = sum((lot.quantity for lot in lots), ZERO)

    result = simulate_sale(portfolio, symbol="BTC", quantity=Decimal("0.75"))

    assert result.remaining_quantity == held - Decimal("0.75")
    assert result.remaining_cost_basis == (
        sum((lot.cost_basis for lot in lots), ZERO) - result.cost_basis
    )
    assert result.remaining_lots == 1
    assert result.remaining_market_value() == result.remaining_quantity * result.price


def test_selling_the_whole_position_leaves_nothing(portfolio: Portfolio) -> None:
    """The walk runs out of lots rather than out of units."""
    result = simulate_sale(portfolio, symbol="BTC", quantity=Decimal("2.10"))

    assert len(result.consumed) == 2
    assert all(row.exhausted for row in result.consumed)
    assert result.remaining_quantity == ZERO
    assert result.remaining_lots == 0
    assert result.remaining_market_value() == ZERO


def test_a_sale_that_ends_on_a_lot_boundary_takes_no_more(
    portfolio: Portfolio,
) -> None:
    """Exactly one lot's worth stops there, leaving the next lot untouched."""
    result = simulate_sale(portfolio, symbol="BTC", quantity=Decimal("0.25"))

    assert [row.lot_id for row in result.consumed] == ["lot-btc-01"]
    assert result.consumed[0].exhausted
    assert result.remaining_lots == 1
    assert result.remaining_quantity == Decimal("1.85")


def test_a_sale_larger_than_the_position_is_rejected(portfolio: Portfolio) -> None:
    """AC-6, OD-3 — no partial fill; costing out a smaller sale answers nothing."""
    with pytest.raises(PositionTooSmallError, match="holds fewer units than that"):
        simulate_sale(portfolio, symbol="BTC", quantity=Decimal("2.25"))


def test_the_rejection_carries_both_quantities_but_says_neither(
    portfolio: Portfolio,
) -> None:
    """§5 — the figures are attributes; the message is what a 422 body shows."""
    with pytest.raises(PositionTooSmallError) as caught:
        simulate_sale(portfolio, symbol="BTC", quantity=Decimal("2.25"))

    assert caught.value.symbol == "BTC"
    assert caught.value.requested == Decimal("2.25")
    assert caught.value.held == Decimal("2.10")
    assert "2.10" not in caught.value.detail


def test_a_symbol_in_the_market_but_not_held_reports_holding_none() -> None:
    """AC-6 — "you hold none" is the honest answer, not an empty success."""
    with pytest.raises(PositionTooSmallError) as caught:
        simulate_sale(make_portfolio(), symbol="AAVE", quantity=Decimal(1))

    assert caught.value.held == ZERO


@pytest.mark.parametrize(
    "quantity", ["0", "-0.5"], ids=["nothing_at_all", "a_purchase_in_disguise"]
)
def test_a_non_positive_sale_is_rejected(portfolio: Portfolio, quantity: str) -> None:
    """AC-6 — a sale of zero or fewer units is not a scenario."""
    with pytest.raises(SaleQuantityError, match="positive number of units"):
        simulate_sale(portfolio, symbol="BTC", quantity=Decimal(quantity))


def test_an_unknown_symbol_is_rejected_before_the_position_is_read(
    portfolio: Portfolio,
) -> None:
    """An unknown ticker beats "you hold none of it": the symbol check is first."""
    with pytest.raises(SymbolNotFoundError, match="not in the market reference"):
        simulate_sale(portfolio, symbol="XYZ", quantity=Decimal(1))


def test_a_simulation_whose_rows_do_not_reach_its_totals_does_not_close() -> None:
    """``closes()`` can fail, or asserting it elsewhere would prove nothing."""
    row = LotConsumption(
        lot_id="lot-btc-01",
        acquired_on=FROZEN_NOW.date(),
        term=LotTerm.SHORT,
        quantity=Decimal(1),
        cost_basis=Decimal(10),
        proceeds=Decimal(15),
        gain_loss=Decimal(5),
        exhausted=True,
    )
    broken = SaleSimulation(
        symbol="BTC",
        price=Decimal("64250.00"),
        quantity=Decimal(1),
        proceeds=Decimal(99),
        cost_basis=Decimal(10),
        realized_pl=Decimal(89),
        remaining_quantity=ZERO,
        remaining_cost_basis=ZERO,
        remaining_lots=0,
        consumed=(row,),
    )

    assert not broken.closes()
