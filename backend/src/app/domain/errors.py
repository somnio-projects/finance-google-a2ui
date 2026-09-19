"""Errors raised by the portfolio domain (spec 0003 §3).

They subclass the ``app.core.errors`` hierarchy, so the RFC 9457 handler
already renders them correctly the day Epic 1 puts a controller in front of
this package.
"""

from decimal import Decimal

from app.core.errors import NotFoundError, ValidationFailedError


class SymbolNotFoundError(NotFoundError):
    """The symbol is not part of the curated market reference."""

    code = "portfolio/unknown-symbol"


class PortfolioInvariantError(ValidationFailedError):
    """A portfolio holding or lot violates a domain invariant."""

    code = "portfolio/invariant-violated"


class WindowOutOfRangeError(ValidationFailedError):
    """The requested price-series window is negative."""

    code = "portfolio/invalid-window"


class SaleQuantityError(ValidationFailedError):
    """The simulated sale is not for a positive number of units."""

    code = "portfolio/invalid-sale-quantity"


class PositionTooSmallError(ValidationFailedError):
    """The simulated sale asks for more units than the position holds."""

    code = "portfolio/position-too-small"

    def __init__(self, *, symbol: str, requested: Decimal, held: Decimal) -> None:
        """Record what was asked for and what is there.

        The two quantities are **attributes**, not part of the message: the
        message is what an RFC 9457 body would render, and how much of a
        symbol someone holds does not belong in one (spec 0013 §5). The tool
        that catches this formats them for the model instead.

        Args:
            symbol: The canonical ticker the sale named.
            requested: Units the sale asked to dispose of.
            held: Units the position actually holds.
        """
        self.symbol = symbol
        self.requested = requested
        self.held = held
        super().__init__(f"the position in {symbol} holds fewer units than that")


__all__ = [
    "PortfolioInvariantError",
    "PositionTooSmallError",
    "SaleQuantityError",
    "SymbolNotFoundError",
    "WindowOutOfRangeError",
]
