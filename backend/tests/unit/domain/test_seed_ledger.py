"""The curated ledger reconciles with the lots it produced (spec 0035 AC-3/AC-4).

These assertions are walked **from the data**, not written down beside it: a
literal list of expected quantities would be the seed restated, and would go
green on the day somebody changed both copies and neither was right. What is
asserted is the *rule* `seed_ledger.py` documents — for every symbol,
``buys - sells == the open lot``, to the unit and to the cent.

Mutation checked: change one quantity in `_BUYS` (or one `cost_basis` in
`SEEDED_LOTS`) by a single unit and
``test_every_sold_symbol_reconciles_with_its_open_lot`` fails naming the
symbol.
"""

from collections import Counter
from decimal import Decimal

import pytest

from app.domain.portfolio import Portfolio
from app.domain.transactions import TransactionType

#: Spec 0035 AC-3. Not "more than a few": the numbers are the deliverable —
#: every chip has to come back with a list worth looking at.
EXPECTED_KINDS = {"buy": 16, "sell": 7, "dividend": 16, "deposit": 9}
#: Bought and fully sold on purpose (OD-7), so the timeline shows a closed
#: position the holdings list correctly does not carry.
ROUND_TRIP = "TSLA"


def test_the_ledger_has_enough_of_every_kind_to_be_worth_filtering(
    portfolio: Portfolio,
) -> None:
    counted = Counter(row.kind.value for row in portfolio.ledger)
    assert dict(counted) == EXPECTED_KINDS
    assert sum(EXPECTED_KINDS.values()) == len(portfolio.ledger) == 48


def test_every_transaction_id_is_unique(portfolio: Portfolio) -> None:
    """The id is the row's key in the payload and the same-date tiebreak."""
    ids = [row.transaction_id for row in portfolio.ledger]
    assert len(set(ids)) == len(ids)


def test_amount_is_quantity_times_price_for_every_row(portfolio: Portfolio) -> None:
    """One invariant covers all four kinds (`Transaction`'s docstring)."""
    for row in portfolio.ledger:
        assert row.amount == row.quantity * row.price, row.transaction_id


@pytest.mark.parametrize("kind", ["buy", "sell"], ids=["buys", "sells"])
def test_every_traded_symbol_is_one_the_market_reference_prices(
    portfolio: Portfolio, kind: str
) -> None:
    for row in portfolio.ledger:
        if row.kind.value == kind:
            assert portfolio.price(row.symbol) > 0, row.symbol


def test_every_sold_symbol_reconciles_with_its_open_lot(portfolio: Portfolio) -> None:
    """The rule `seed_ledger.py` states, checked rather than trusted (AC-4)."""
    sold = {row.symbol for row in portfolio.ledger if row.kind is TransactionType.SELL}
    assert len(sold) == EXPECTED_KINDS["sell"], (
        "one sale per symbol, so each walks alone"
    )
    for symbol in sorted(sold):
        bought = sum(
            (
                row.quantity
                for row in portfolio.ledger
                if row.symbol == symbol and row.kind is TransactionType.BUY
            ),
            Decimal(0),
        )
        disposed = sum(
            (
                row.quantity
                for row in portfolio.ledger
                if row.symbol == symbol and row.kind is TransactionType.SELL
            ),
            Decimal(0),
        )
        held = sum((lot.quantity for lot in portfolio.tax_lots(symbol)), Decimal(0))
        assert bought - disposed == held, symbol


def test_the_round_trip_symbol_is_held_by_no_lot(portfolio: Portfolio) -> None:
    """A closed position: the ledger remembers it, the holdings do not."""
    assert portfolio.tax_lots(ROUND_TRIP) == []
    assert any(row.symbol == ROUND_TRIP for row in portfolio.ledger)


def test_the_remaining_cost_basis_is_what_the_sale_did_not_consume(
    portfolio: Portfolio,
) -> None:
    """The cent half of AC-4, which the quantity half cannot catch."""
    for symbol in sorted({lot.symbol for lot in portfolio.lots} - {"USD"}):
        paid = sum(
            (
                row.amount
                for row in portfolio.ledger
                if row.symbol == symbol and row.kind is TransactionType.BUY
            ),
            Decimal(0),
        )
        consumed = sum(
            (
                row.quantity
                * next(
                    buy.price
                    for buy in portfolio.ledger
                    if buy.symbol == symbol and buy.kind is TransactionType.BUY
                )
                for row in portfolio.ledger
                if row.symbol == symbol and row.kind is TransactionType.SELL
            ),
            Decimal(0),
        )
        basis = sum((lot.cost_basis for lot in portfolio.tax_lots(symbol)), Decimal(0))
        assert paid - consumed == basis, symbol


def test_the_portfolio_the_richer_ledger_belongs_to_still_validates(
    portfolio: Portfolio,
) -> None:
    """No lot moved (OD-7), so every 0025 figure still holds."""
    portfolio.validate()
    assert portfolio.total_market_value() == Decimal("482915.20")
