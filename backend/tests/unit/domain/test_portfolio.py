"""AC-4 — the read surface is deterministic, forgiving and totally ordered."""

from datetime import timedelta

import pytest

from app.domain.errors import PortfolioInvariantError, SymbolNotFoundError
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio
from tests.conftest import FROZEN_NOW
from tests.unit.domain.conftest import make_lot


def test_holdings_returns_the_same_order_on_repeated_calls(
    portfolio: Portfolio,
) -> None:
    first = [holding.symbol for holding in portfolio.holdings()]
    second = [holding.symbol for holding in portfolio.holdings()]
    assert (
        first
        == second
        == [
            "BTC",
            "ETH",
            "SOL",
            "LINK",
            "AAVE",
            "ARB",
            "USDC",
        ]
    )


def test_holdings_returns_a_copy_the_caller_cannot_corrupt(
    portfolio: Portfolio,
) -> None:
    holdings = portfolio.holdings()
    holdings.clear()
    assert len(portfolio.holdings()) == 7


@pytest.mark.parametrize(
    "written",
    ["BTC", "btc", " btc ", "bTc"],
    ids=["upper", "lower", "padded", "mixed"],
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
    # txn-0009 and txn-0010 share a date on purpose (seed_ledger.py).
    paired = next(row for row in rows if row.transaction_id == "txn-0009").occurred_on
    same_day = [row.transaction_id for row in rows if row.occurred_on == paired]
    assert same_day == ["txn-0009", "txn-0010"]
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


def test_total_market_value_sums_every_holding(portfolio: Portfolio) -> None:
    expected = sum((row.market_value for row in portfolio.positions), ZERO)

    assert portfolio.total_market_value() == expected


def test_total_cost_basis_sums_every_holding(portfolio: Portfolio) -> None:
    expected = sum((row.cost_basis for row in portfolio.positions), ZERO)

    assert portfolio.total_cost_basis() == expected


def test_total_unrealized_pl_is_the_difference_of_the_other_two(
    portfolio: Portfolio,
) -> None:
    assert portfolio.total_unrealized_pl() == (
        portfolio.total_market_value() - portfolio.total_cost_basis()
    )


def test_the_totals_agree_with_each_holdings_own_unrealised_pl(
    portfolio: Portfolio,
) -> None:
    """The reason the totals live on the aggregate at all.

    The agent says one of these numbers out loud while a chart draws another.
    If they were computed in two places they could drift; computed here they
    cannot, and this asserts the identity that makes that true.
    """
    per_holding = sum((row.unrealized_pl for row in portfolio.positions), ZERO)

    assert portfolio.total_unrealized_pl() == per_holding


def test_an_empty_portfolio_totals_to_zero_rather_than_failing(
    portfolio: Portfolio,
) -> None:
    empty = Portfolio(
        as_of=portfolio.as_of, positions=(), lots=(), ledger=portfolio.ledger
    )

    assert empty.total_market_value() == ZERO
    assert empty.total_cost_basis() == ZERO
    assert empty.total_unrealized_pl() == ZERO
