"""AC-1, AC-6, AC-7 — the seed validates, reconciles and demos something.

Without the flow cases the seed silently drifts into a portfolio that demos
nothing: no near-boundary lot for the tax flow, no loser for the attribution
story. The suite stays green and the demo dies.
"""

from datetime import datetime, timedelta

import pytest

from app.domain.market import price_of
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio
from app.domain.seed import seed_portfolio
from app.domain.terms import LONG_TERM_DAYS, holding_period_days
from tests.conftest import FROZEN_NOW

BOUNDARY_TOLERANCE_DAYS = 5


def test_seed_portfolio_at_fixed_as_of_validates(portfolio: Portfolio) -> None:
    portfolio.validate()
    assert portfolio.as_of == FROZEN_NOW
    assert portfolio.holdings()
    assert portfolio.lots
    assert portfolio.transactions()
    assert portfolio.price_series("BTC", timedelta(days=30))


def test_seed_portfolio_is_deterministic_for_the_same_as_of() -> None:
    assert seed_portfolio(as_of=FROZEN_NOW) == seed_portfolio(as_of=FROZEN_NOW)


def test_seed_portfolio_rejects_a_naive_as_of() -> None:
    with pytest.raises(ValueError, match="requires an aware as_of"):
        seed_portfolio(as_of=datetime(2026, 9, 18, 12, 0))


def test_every_seeded_symbol_reconciles_with_the_market_reference(
    portfolio: Portfolio,
) -> None:
    for holding in portfolio.holdings():
        assert holding.price == price_of(holding.symbol)
    for lot in portfolio.lots:
        assert price_of(lot.symbol) > 0


def test_seed_aggregates_tie_out_by_hand(portfolio: Portfolio) -> None:
    btc = portfolio.holdings()[0]
    lots = portfolio.tax_lots("BTC")
    assert btc.quantity == sum((lot.quantity for lot in lots), ZERO)
    assert btc.cost_basis == sum((lot.cost_basis for lot in lots), ZERO)
    assert btc.market_value == btc.quantity * portfolio.price("BTC")
    assert btc.unrealized_pl == btc.market_value - btc.cost_basis


def test_seeded_transactions_tie_amount_to_quantity_times_price(
    portfolio: Portfolio,
) -> None:
    for row in portfolio.transactions():
        assert row.amount == row.quantity * row.price


def test_seed_contains_a_lot_near_the_one_year_boundary(portfolio: Portfolio) -> None:
    as_of = portfolio.as_of.date()
    distances = [
        abs(holding_period_days(lot.acquired_on, as_of=as_of) - LONG_TERM_DAYS)
        for lot in portfolio.lots
    ]
    assert min(distances) <= BOUNDARY_TOLERANCE_DAYS


def test_seed_contains_a_winner_and_a_loser(portfolio: Portfolio) -> None:
    results = [holding.unrealized_pl for holding in portfolio.holdings()]
    assert any(result > 0 for result in results)
    assert any(result < 0 for result in results)


def test_seed_contains_a_holding_with_lots_of_differing_term(
    portfolio: Portfolio,
) -> None:
    as_of = portfolio.as_of.date()
    mixed = [
        holding.symbol
        for holding in portfolio.holdings()
        if len({lot.term(as_of) for lot in portfolio.tax_lots(holding.symbol)}) > 1
    ]
    assert "BTC" in mixed
