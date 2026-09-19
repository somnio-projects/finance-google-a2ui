"""Build the curated demo portfolio at an injected ``as_of`` (spec 0003 AC-1).

``as_of`` is a parameter, never a wall-clock read: ``datetime.now()`` appears
nowhere in this package (ADR-F D-6, spec 0003 AC-9). Fixing it at seed time is
what keeps a lot sitting on the 1-year boundary from flipping term between two
questions in the same conversation.

Aggregates are derived from the lots here, so the seed cannot disagree with
itself; ``Portfolio.validate`` is what proves the derivation still holds, and
its negative tests are what prove ``validate`` can fail at all.
"""

from collections.abc import Sequence
from datetime import datetime, timedelta
from decimal import Decimal

from app.domain.holdings import Holding
from app.domain.lots import TaxLot
from app.domain.market import market_asset, price_of
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio
from app.domain.seed_data import (
    SEEDED_LOTS,
    SEEDED_TRANSACTIONS,
    LotRow,
    TransactionRow,
)
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
    )


def _ordered_symbols(lots: Sequence[TaxLot]) -> list[str]:
    """Return the distinct symbols in first-appearance (seed) order."""
    symbols: list[str] = []
    for lot in lots:
        if lot.symbol not in symbols:
            symbols.append(lot.symbol)
    return symbols


def _value_of(symbol: str, lots: Sequence[TaxLot]) -> Decimal:
    """Return the market value of one symbol's lots at the reference price."""
    return sum((lot.quantity for lot in lots), ZERO) * price_of(symbol)


def _to_holding(symbol: str, lots: Sequence[TaxLot], total_value: Decimal) -> Holding:
    """Aggregate one symbol's lots into a ``Holding``."""
    asset = market_asset(symbol)
    quantity = sum((lot.quantity for lot in lots), ZERO)
    cost_basis = sum((lot.cost_basis for lot in lots), ZERO)
    market_value = quantity * asset.price
    return Holding(
        symbol=asset.symbol,
        name=asset.name,
        quantity=quantity,
        price=asset.price,
        market_value=market_value,
        cost_basis=cost_basis,
        unrealized_pl=market_value - cost_basis,
        weight=market_value / total_value,
    )


def _to_holdings(lots: Sequence[TaxLot]) -> tuple[Holding, ...]:
    """Aggregate every lot into one holding per symbol, in seed order."""
    grouped = {
        symbol: [lot for lot in lots if lot.symbol == symbol]
        for symbol in _ordered_symbols(lots)
    }
    total_value = sum(
        (_value_of(symbol, symbol_lots) for symbol, symbol_lots in grouped.items()),
        ZERO,
    )
    return tuple(
        _to_holding(symbol, symbol_lots, total_value)
        for symbol, symbol_lots in grouped.items()
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
        positions=_to_holdings(lots),
        lots=lots,
        ledger=tuple(_to_transaction(row, as_of=as_of) for row in SEEDED_TRANSACTIONS),
    )


__all__ = ["seed_portfolio"]
