"""``realized_of`` — what a past sale realised, read from the ledger (spec 0028)."""

from datetime import date
from decimal import Decimal

from app.domain.activity import realized_of
from app.domain.portfolio import Portfolio
from app.domain.terms import LotTerm
from app.domain.transactions import Transaction, TransactionType


def _row(
    txn_id: str, day: date, kind: TransactionType, qty: str, price: str
) -> Transaction:
    quantity, unit = Decimal(qty), Decimal(price)
    return Transaction(
        transaction_id=txn_id,
        occurred_on=day,
        kind=kind,
        symbol="SOL",
        quantity=quantity,
        price=unit,
        amount=quantity * unit,
    )


def test_the_seeded_btc_sale_realised_a_short_term_gain(portfolio: Portfolio) -> None:
    sale = next(
        row
        for row in portfolio.ledger
        if row.kind is TransactionType.SELL and row.transaction_id == "txn-0015"
    )
    realized = realized_of(sale, portfolio.ledger)
    assert realized is not None
    # 0.25 BTC sold at $58,400 against the $36,000 it was bought at, 307 days on.
    assert realized.amount == Decimal("5600.00")
    assert realized.term is LotTerm.SHORT


def test_a_sale_across_two_buys_consumes_the_oldest_first() -> None:
    ledger = (
        _row("buy-1", date(2024, 1, 1), TransactionType.BUY, "10", "100"),
        _row("buy-2", date(2025, 6, 1), TransactionType.BUY, "10", "200"),
        _row("sell-1", date(2026, 1, 1), TransactionType.SELL, "15", "300"),
    )
    realized = realized_of(ledger[2], ledger)
    assert realized is not None
    # 10 @ 100 + 5 @ 200 = 2,000 of basis against 4,500 of proceeds.
    assert realized.amount == Decimal("2500")
    # The newer buy was held under a year, so the row is short.
    assert realized.term is LotTerm.SHORT


def test_every_buy_older_than_a_year_makes_the_sale_long_term() -> None:
    ledger = (
        _row("buy-1", date(2024, 1, 1), TransactionType.BUY, "10", "100"),
        _row("sell-1", date(2026, 1, 1), TransactionType.SELL, "10", "90"),
    )
    realized = realized_of(ledger[1], ledger)
    assert realized is not None
    assert realized.amount == Decimal("-100")
    assert realized.term is LotTerm.LONG


def test_a_sale_the_ledger_cannot_cover_has_no_result() -> None:
    ledger = (
        _row("buy-1", date(2024, 1, 1), TransactionType.BUY, "5", "100"),
        _row("later", date(2026, 2, 1), TransactionType.BUY, "50", "100"),
        _row("sell-1", date(2026, 1, 1), TransactionType.SELL, "10", "300"),
    )
    assert realized_of(ledger[2], ledger) is None
