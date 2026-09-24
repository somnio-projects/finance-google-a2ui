"""Build the curated demo portfolio at an injected ``as_of`` (spec 0003 AC-1).

``as_of`` is a parameter, never a wall-clock read: ``datetime.now()`` appears
nowhere in this package (ADR-F D-6, spec 0003 AC-9). Fixing it at seed time is
what keeps a lot sitting on the 1-year boundary from flipping term between two
questions in the same conversation.

Aggregates are derived from the lots here, so the seed cannot disagree with
itself; ``Portfolio.validate`` is what proves the derivation still holds, and
its negative tests are what prove ``validate`` can fail at all.
"""

from datetime import datetime, timedelta
from decimal import Decimal

from app.domain.derivation import holdings_from
from app.domain.lots import TaxLot
from app.domain.portfolio import Portfolio
from app.domain.seed_data import SEEDED_LOTS, LotRow
from app.domain.seed_ledger import SEEDED_TRANSACTIONS, TransactionRow
from app.domain.transactions import Transaction, TransactionType


def _to_lot(row: LotRow, *, as_of: datetime) -> TaxLot:
    """Turn one curated row into a validated ``TaxLot``."""
    return TaxLot(
        lot_id=row.lot_id,
        symbol=row.symbol,
        acquired_on=(as_of - timedelta(days=row.days_before)).date(),
        quantity=Decimal(row.quantity),
        cost_basis=Decimal(row.cost_basis),
    )


def _to_transaction(row: TransactionRow, *, as_of: datetime) -> Transaction:
    """Turn one curated row into a validated ``Transaction``."""
    return Transaction(
        transaction_id=row.transaction_id,
        occurred_on=(as_of - timedelta(days=row.days_before)).date(),
        kind=TransactionType(row.kind),
        symbol=row.symbol,
        quantity=Decimal(row.quantity),
        price=Decimal(row.price),
        amount=Decimal(row.amount),
        memo=row.memo,
    )


def seed_portfolio(*, as_of: datetime) -> Portfolio:
    """Build the curated demo portfolio as it stands at ``as_of``.

    Args:
        as_of: The instant the demo reads the portfolio at; must be aware.

    Returns:
        An invariant-clean portfolio, identical for an identical ``as_of``.

    Raises:
        ValueError: When ``as_of`` is naive. An ambiguous instant would make
            the lot-term boundary ambiguous with it.
    """
    if as_of.tzinfo is None:
        msg = f"seed_portfolio requires an aware as_of, got {as_of!r}"
        raise ValueError(msg)
    lots = tuple(_to_lot(row, as_of=as_of) for row in SEEDED_LOTS)
    return Portfolio(
        as_of=as_of,
        positions=holdings_from(lots),
        lots=lots,
        ledger=tuple(_to_transaction(row, as_of=as_of) for row in SEEDED_TRANSACTIONS),
    )


__all__ = ["seed_portfolio"]
