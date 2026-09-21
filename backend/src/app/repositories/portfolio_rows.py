"""Convert between the portfolio aggregate and its rows (spec 0020).

Split from ``portfolio_repository`` under the 150-line budget, along the seam
that was already there: the repository decides **which** rows to read and
write, this decides **what a row is**.

Nothing here rounds, formats or recomputes. A ``Decimal`` written is the
``Decimal`` read (ADR-E D-5) — the column is ``NUMERIC(38, 18)`` precisely so
this conversion can be lossless, and spec 0020 AC-4 asserts it to the last
place rather than approximately.
"""

from collections.abc import Sequence
from uuid import UUID

from app.domain.derivation import holdings_from
from app.domain.holdings import Holding
from app.domain.lots import TaxLot
from app.domain.transactions import Transaction, TransactionType
from app.models.portfolio import PortfolioLot, PortfolioTransaction


def positions_of(lots: Sequence[TaxLot]) -> tuple[Holding, ...]:
    """Rebuild the holdings of a loaded portfolio from its lots.

    Deliberately a re-derivation rather than a read: positions are not stored
    (spec 0020 §3), so this and the seed produce them through the same
    ``holdings_from`` and cannot disagree.

    Args:
        lots: The open lots read back for one portfolio.

    Returns:
        One holding per symbol, in first-seen order.
    """
    return holdings_from(lots)


def lot_row(portfolio_id: UUID, lot: TaxLot) -> PortfolioLot:
    """Return the row that stores ``lot``.

    Args:
        portfolio_id: The owning portfolio.
        lot: The domain lot to persist.

    Returns:
        An unsaved ORM row.
    """
    return PortfolioLot(
        portfolio_id=portfolio_id,
        lot_id=lot.lot_id,
        symbol=lot.symbol,
        acquired_on=lot.acquired_on,
        quantity=lot.quantity,
        cost_basis=lot.cost_basis,
    )


def transaction_row(
    portfolio_id: UUID, transaction: Transaction
) -> PortfolioTransaction:
    """Return the row that stores ``transaction``.

    Args:
        portfolio_id: The owning portfolio.
        transaction: The domain ledger entry to persist.

    Returns:
        An unsaved ORM row.
    """
    return PortfolioTransaction(
        portfolio_id=portfolio_id,
        transaction_id=transaction.transaction_id,
        occurred_on=transaction.occurred_on,
        kind=transaction.kind.value,
        symbol=transaction.symbol,
        quantity=transaction.quantity,
        price=transaction.price,
        amount=transaction.amount,
    )


def lot_of(row: PortfolioLot) -> TaxLot:
    """Return the domain lot ``row`` stores.

    Args:
        row: The persisted lot.

    Returns:
        The validated domain entity, with its ``Decimal`` untouched.
    """
    return TaxLot(
        lot_id=row.lot_id,
        symbol=row.symbol,
        acquired_on=row.acquired_on,
        quantity=row.quantity,
        cost_basis=row.cost_basis,
    )


def transaction_of(row: PortfolioTransaction) -> Transaction:
    """Return the domain ledger entry ``row`` stores.

    Args:
        row: The persisted transaction.

    Returns:
        The validated domain entity, with its ``Decimal`` untouched.
    """
    return Transaction(
        transaction_id=row.transaction_id,
        occurred_on=row.occurred_on,
        kind=TransactionType(row.kind),
        symbol=row.symbol,
        quantity=row.quantity,
        price=row.price,
        amount=row.amount,
    )


__all__ = [
    "lot_of",
    "lot_row",
    "positions_of",
    "transaction_of",
    "transaction_row",
]
