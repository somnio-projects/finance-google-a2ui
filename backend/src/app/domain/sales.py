"""Costing a proposed sale against the lots it would consume (spec 0013).

This answers *"what if I sold 0.5 BTC?"* — which is not the question
``app.domain.holdings`` answers. A holding compares a **whole** position to
what it cost; a sale consumes **specific lots**, in an order the caller
chooses, and splits the result by holding period. Sell the same units under
FIFO and under HIFO and the tax picture differs, which is the entire point of
the comparator.

Read-only by construction: it takes a ``Portfolio`` and returns a result, and
never calls ``PortfolioProvider.save`` — a what-if cannot become a trade by
accident. Pure and deterministic with it: the price and ``as_of`` come from
the portfolio, the lot order is total (``app.domain.lot_selection``), and
nothing here reads a clock (ADR-F D-6).
"""

from collections.abc import Sequence
from datetime import date
from decimal import Decimal

from app.domain.errors import PositionTooSmallError, SaleQuantityError
from app.domain.lot_selection import LotMethod, consumption_order
from app.domain.lots import TaxLot
from app.domain.money import ZERO
from app.domain.portfolio import Portfolio
from app.domain.sale_results import LotConsumption, SaleSimulation
from app.domain.symbols import normalize_symbol


def _open_lots(portfolio: Portfolio, *, symbol: str, quantity: Decimal) -> list[TaxLot]:
    """Return the lots a sale of ``quantity`` units may consume.

    Args:
        portfolio: The portfolio to read.
        symbol: An already-canonical ticker.
        quantity: Units the sale asks to dispose of.

    Returns:
        The symbol's open lots, in seed order.

    Raises:
        SaleQuantityError: When ``quantity`` is not positive — selling
            nothing is not a scenario.
        PositionTooSmallError: When the position holds fewer units. Never a
            partial fill: costing out a smaller sale answers a question the
            caller did not ask (spec 0013 OD-3).
    """
    if quantity <= ZERO:
        msg = f"a sale must be for a positive number of units, got {quantity}"
        raise SaleQuantityError(msg)
    lots = portfolio.tax_lots(symbol)
    held = sum((lot.quantity for lot in lots), ZERO)
    if quantity > held:
        raise PositionTooSmallError(symbol=symbol, requested=quantity, held=held)
    return lots


def _consume(
    lots: Sequence[TaxLot], *, quantity: Decimal, price: Decimal, as_of: date
) -> list[LotConsumption]:
    """Take ``quantity`` units out of ``lots``, in the order given.

    Args:
        lots: The open lots, already in consumption order.
        quantity: Units to take; never more than the lots hold.
        price: The price every consumed unit is sold at.
        as_of: The day the terms are classified against.

    Returns:
        One row per lot touched, in the order they were touched. The last row
        is partial whenever the sale stops mid-lot.
    """
    rows: list[LotConsumption] = []
    left = quantity
    for lot in lots:
        if left == ZERO:
            break
        taken = min(left, lot.quantity)
        basis = lot.cost_basis * taken / lot.quantity
        rows.append(
            LotConsumption(
                lot_id=lot.lot_id,
                acquired_on=lot.acquired_on,
                term=lot.term(as_of),
                quantity=taken,
                cost_basis=basis,
                proceeds=taken * price,
                gain_loss=taken * price - basis,
                exhausted=taken == lot.quantity,
            )
        )
        left -= taken
    return rows


def simulate_sale(
    portfolio: Portfolio,
    *,
    symbol: str,
    quantity: Decimal,
    method: LotMethod = LotMethod.FIFO,
) -> SaleSimulation:
    """Cost a proposed sale of ``quantity`` units of ``symbol``.

    Args:
        portfolio: The portfolio to read; never fetched and never saved here.
        symbol: A ticker in any case, normalised before anything else.
        quantity: Units to dispose of; must be positive and held.
        method: Which lots the sale consumes first.

    Returns:
        The simulation: the lots consumed, the totals they sum to, and what
        the position looks like afterwards. The totals are computed from the
        rows, so ``SaleSimulation.closes()`` holds by construction rather
        than by luck.

    Raises:
        SymbolNotFoundError: When the ticker is not in the market reference —
            checked first, because "no such asset" is a better answer than
            "you hold none of it".
        SaleQuantityError: When ``quantity`` is not positive.
        PositionTooSmallError: When the position holds fewer units.
    """
    canonical = normalize_symbol(symbol)
    price = portfolio.price(canonical)
    lots = _open_lots(portfolio, symbol=canonical, quantity=quantity)
    consumed = _consume(
        consumption_order(lots, method=method),
        quantity=quantity,
        price=price,
        as_of=portfolio.as_of.date(),
    )
    spent = sum((row.cost_basis for row in consumed), ZERO)
    return SaleSimulation(
        symbol=canonical,
        price=price,
        quantity=quantity,
        proceeds=sum((row.proceeds for row in consumed), ZERO),
        cost_basis=spent,
        realized_pl=sum((row.gain_loss for row in consumed), ZERO),
        remaining_quantity=sum((lot.quantity for lot in lots), ZERO) - quantity,
        remaining_cost_basis=sum((lot.cost_basis for lot in lots), ZERO) - spent,
        remaining_lots=len(lots) - sum(1 for row in consumed if row.exhausted),
        consumed=tuple(consumed),
    )


__all__ = ["simulate_sale"]
