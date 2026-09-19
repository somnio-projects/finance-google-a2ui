"""AC-4 — the read surface is deterministic, forgiving and totally ordered."""

from datetime import timedelta

import pytest

from app.domain.errors import PortfolioInvariantError, SymbolNotFoundError
from app.domain.portfolio import Portfolio
from tests.conftest import FROZEN_NOW
from tests.unit.domain.conftest import make_lot


def test_holdings_returns_the_same_order_on_repeated_calls(
    portfolio: Portfolio,
) -> None:
    first = [holding.symbol for holding in portfolio.holdings()]
    second = [holding.symbol for holding in portfolio.holdings()]
    assert first == second == ["BTC", "ETH", "SOL", "LINK", "DOGE"]


def test_holdings_returns_a_copy_the_caller_cannot_corrupt(
    portfolio: Portfolio,
) -> None:
    holdings = portfolio.holdings()
    holdings.clear()
    assert len(portfolio.holdings()) == 5


@pytest.mark.parametrize(
    "written", ["BTC", "btc", " btc ", "bTc"], ids=["upper", "lower", "padded", "mixed"]
)
def test_tax_lots_is_symbol_normalised(portfolio: Portfolio, written: str) -> None:
    assert [lot.lot_id for lot in portfolio.tax_lots(written)] == [
        "lot-btc-01",
        "lot-btc-02",
    ]


def test_tax_lots_of_an_unknown_symbol_is_empty(portfolio: Portfolio) -> None:
    assert portfolio.tax_lots("NOPE") == []


def test_transactions_are_descending_with_a_stable_same_date_tiebreak(
    portfolio: Portfolio,
) -> None:
    rows = portfolio.transactions()
    dates = [row.occurred_on for row in rows]
    assert dates == sorted(dates, reverse=True)
    same_day = [row.transaction_id for row in rows if row.occurred_on == dates[1]]
    assert same_day == ["txn-0006", "txn-0007"]
    assert [row.transaction_id for row in portfolio.transactions()] == [
        row.transaction_id for row in rows
    ]


def test_price_reads_the_market_reference(portfolio: Portfolio) -> None:
    assert portfolio.price("eth") == portfolio.holdings()[1].price


def test_price_of_an_unknown_symbol_raises(portfolio: Portfolio) -> None:
    with pytest.raises(SymbolNotFoundError, match="'NOPE'"):
        portfolio.price("nope")


def test_portfolio_validate_rejects_a_future_lot(portfolio: Portfolio) -> None:
    broken = Portfolio(
        as_of=portfolio.as_of,
        positions=portfolio.positions,
        lots=(*portfolio.lots, make_lot(lot_id="lot-btc-99", days_before=-1)),
        ledger=portfolio.ledger,
    )
    with pytest.raises(PortfolioInvariantError, match=r"lot lot-btc-99 was acquired"):
        broken.validate()


def test_portfolio_is_frozen(portfolio: Portfolio) -> None:
    with pytest.raises(AttributeError, match="as_of"):
        portfolio.as_of = FROZEN_NOW + timedelta(days=1)  # pyright: ignore[reportAttributeAccessIssue]
