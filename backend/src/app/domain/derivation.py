"""Derive holdings from tax lots — the one place that does it (spec 0020 §3).

These functions were private to ``domain/seed``, which was correct while the
seed was the only thing that ever built a portfolio. Persistence added a second
builder: `PortfolioRepository` reads lots back and must produce the same
positions from them.

Two copies of this arithmetic would be the exact failure the derivation exists
to prevent. `Portfolio.validate` proves that positions agree with their lots —
but only for the portfolio it is handed, and it cannot notice that the seeded
one and the loaded one were computed by different code. So there is one
function, and both callers use it.
"""

from collections.abc import Sequence
from decimal import Decimal

from app.domain.holdings import Holding
from app.domain.lots import TaxLot
from app.domain.market import market_asset, price_of
from app.domain.money import ZERO


def ordered_symbols(lots: Sequence[TaxLot]) -> list[str]:
    """Return the distinct symbols in first-appearance order.

    First appearance, never sorted: the seed's order is the order the demo
    tells its story in, and a chart that reorders it tells a different one.

    Args:
        lots: The open lots, in the order they were seeded or read.

    Returns:
        Each symbol once, in the order it first appears.
    """
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


def holdings_from(lots: Sequence[TaxLot]) -> tuple[Holding, ...]:
    """Aggregate every lot into one holding per symbol, in first-seen order.

    Args:
        lots: Every open lot of one portfolio.

    Returns:
        One holding per distinct symbol; empty when there are no lots.
    """
    grouped = {
        symbol: [lot for lot in lots if lot.symbol == symbol]
        for symbol in ordered_symbols(lots)
    }
    total_value = sum(
        (_value_of(symbol, symbol_lots) for symbol, symbol_lots in grouped.items()),
        ZERO,
    )
    return tuple(
        _to_holding(symbol, symbol_lots, total_value)
        for symbol, symbol_lots in grouped.items()
    )


__all__ = ["holdings_from", "ordered_symbols"]
