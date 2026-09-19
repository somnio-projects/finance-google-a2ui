"""The portfolio aggregate — the read surface Epic 1 codes against (spec 0003).

``Portfolio`` is a frozen dataclass rather than a pydantic model for one
concrete reason: its required read method ``validate()`` would shadow
pydantic's deprecated ``BaseModel.validate`` classmethod. Its fields hold
already-validated pydantic entities, and they are named apart from the read
methods (``positions``/``holdings()``, ``ledger``/``transactions()``) so both
can exist on the same object.

Every read is pure and deterministic: the same call twice returns the same
order, and ``as_of`` is fixed at seed time (ADR-F D-6) so nothing here reads a
wall clock.
"""

from dataclasses import dataclass
from datetime import datetime, timedelta
from decimal import Decimal

from app.domain.errors import WindowOutOfRangeError
from app.domain.history import HISTORY_DAYS, price_history
from app.domain.holdings import Holding
from app.domain.invariants import (
    validate_holding,
    validate_lot_dates,
    validate_weights,
)
from app.domain.lots import TaxLot
from app.domain.market import price_of
from app.domain.prices import PricePoint
from app.domain.symbols import normalize_symbol
from app.domain.transactions import Transaction


@dataclass(frozen=True, slots=True)
class Portfolio:
    """One subject's simulated portfolio, read at a fixed ``as_of``."""

    as_of: datetime
    positions: tuple[Holding, ...]
    lots: tuple[TaxLot, ...]
    ledger: tuple[Transaction, ...]

    def holdings(self) -> list[Holding]:
        """Return every holding in a stable order (seed order, never a set)."""
        return list(self.positions)

    def tax_lots(self, symbol: str) -> list[TaxLot]:
        """Return the open lots of ``symbol``, or ``[]`` for an unknown one.

        Args:
            symbol: A ticker in any case, with or without whitespace.

        Returns:
            The lots in seed order; an empty list is not an error.
        """
        canonical = normalize_symbol(symbol)
        return [lot for lot in self.lots if lot.symbol == canonical]

    def transactions(self) -> list[Transaction]:
        """Return the ledger newest first, ties broken by ``transaction_id``.

        Returns:
            The rows sorted descending by date; same-date rows keep an
            ascending ``transaction_id`` order, so the result is total and
            stable rather than merely sorted.
        """
        by_id = sorted(self.ledger, key=lambda row: row.transaction_id)
        return sorted(by_id, key=lambda row: row.occurred_on, reverse=True)

    def price(self, symbol: str) -> Decimal:
        """Return the current reference price of ``symbol``.

        Args:
            symbol: A ticker in any case.

        Returns:
            The market reference price — the one source of price for everyone.
        """
        return price_of(symbol)

    def price_series(self, symbol: str, window: timedelta) -> list[PricePoint]:
        """Return the daily price series of ``symbol`` over ``window``.

        The generated history is ``HISTORY_DAYS`` points ending at ``as_of``.
        A window wider than the history **truncates** to what exists: it never
        raises and never fabricates older points. A zero window returns exactly
        one point, ``as_of`` at the current price. A negative window is a
        programming error, not a truncation.

        Args:
            symbol: A ticker in any case.
            window: How far back to go from ``as_of``.

        Returns:
            The points ascending by date; the last one is the current price.

        Raises:
            WindowOutOfRangeError: When ``window`` is negative.
        """
        if window < timedelta(0):
            msg = f"price window must not be negative, got {window}"
            raise WindowOutOfRangeError(msg)
        points = min(window.days, HISTORY_DAYS - 1) + 1
        return list(price_history(symbol, as_of=self.as_of.date(), points=points))

    def validate(self) -> None:
        """Check every invariant of the portfolio (ADR-E D-4).

        Raises:
            PortfolioInvariantError: On the first violation, naming the
                offending holding.
        """
        as_of_date = self.as_of.date()
        validate_lot_dates(self.lots, as_of=as_of_date)
        for holding in self.positions:
            validate_holding(
                holding,
                lots=self.tax_lots(holding.symbol),
                price=self.price(holding.symbol),
            )
        validate_weights(self.positions)


__all__ = ["Portfolio"]
