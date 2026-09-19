"""Errors raised by the portfolio domain (spec 0003 §3).

They subclass the ``app.core.errors`` hierarchy, so the RFC 9457 handler
already renders them correctly the day Epic 1 puts a controller in front of
this package.
"""

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


__all__ = ["PortfolioInvariantError", "SymbolNotFoundError", "WindowOutOfRangeError"]
