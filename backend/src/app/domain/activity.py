"""What a ledger sale realised — the figure the Activity tab prints beside it.

The tax-lot views walk the **open** lots a future sale would consume. A sale
that already happened consumed buys that are no longer lots, so its result is
read from the ledger: the buys of the same symbol that preceded it, oldest
first, until the sold quantity is covered (spec 0028 OD-3). Each sale is
walked on its own; the simulation has one sale, and a second one would
share the walk's buys — a known simplification, recorded in the spec.
"""

from collections.abc import Sequence
from datetime import date
from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.money import ZERO
from app.domain.terms import LONG_TERM_DAYS, LotTerm
from app.domain.transactions import Transaction, TransactionType


class Realized(BaseModel):
    """The result of one past sale."""

    model_config = ConfigDict(frozen=True)

    amount: Decimal = Field(description="Proceeds minus the basis consumed.")
    term: LotTerm = Field(description="Long only if every consumed buy was.")


class _Consumed(BaseModel):
    """What the walk over the buys took: its cost, and whether all was long."""

    model_config = ConfigDict(frozen=True)

    cost: Decimal
    every_buy_long: bool


def _buys_before(sale: Transaction, ledger: Sequence[Transaction]) -> list[Transaction]:
    """The buys of the sale's symbol up to its day, oldest first."""
    return sorted(
        (
            row
            for row in ledger
            if row.symbol == sale.symbol
            and row.kind is TransactionType.BUY
            and row.occurred_on <= sale.occurred_on
        ),
        key=lambda row: (row.occurred_on, row.transaction_id),
    )


def _is_long(buy: Transaction, *, sold_on: date) -> bool:
    """Whether ``buy`` had been held past the long-term line when sold."""
    return (sold_on - buy.occurred_on).days > LONG_TERM_DAYS


def _consume(
    buys: Sequence[Transaction], *, quantity: Decimal, sold_on: date
) -> _Consumed | None:
    """Take ``quantity`` from ``buys`` in order; None when they cannot cover it."""
    remaining = quantity
    cost = ZERO
    every_buy_long = True
    for buy in buys:
        taken = min(buy.quantity, remaining)
        cost += taken * buy.price
        every_buy_long = every_buy_long and _is_long(buy, sold_on=sold_on)
        remaining -= taken
        if remaining <= ZERO:
            break
    if remaining > ZERO:
        return None
    return _Consumed(cost=cost, every_buy_long=every_buy_long)


def realized_of(sale: Transaction, ledger: Sequence[Transaction]) -> Realized | None:
    """Return what ``sale`` realised, or None when the ledger lacks its basis."""
    consumed = _consume(
        _buys_before(sale, ledger), quantity=sale.quantity, sold_on=sale.occurred_on
    )
    if consumed is None:
        return None
    return Realized(
        amount=sale.amount - consumed.cost,
        term=LotTerm.LONG if consumed.every_buy_long else LotTerm.SHORT,
    )


__all__ = ["Realized", "realized_of"]
