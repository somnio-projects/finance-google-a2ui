"""Ticker-symbol shape shared by every entity in the portfolio domain.

Symbols are stored upper-case and matched after normalisation, so a caller may
ask for ``BTC``, ``btc`` or ``" btc "`` and get the same answer (spec 0003
AC-4).
"""

from typing import Final

SYMBOL_PATTERN: Final[str] = r"^[A-Z]{2,10}$"


def normalize_symbol(symbol: str) -> str:
    """Return ``symbol`` stripped of whitespace and upper-cased.

    Args:
        symbol: A ticker as the caller typed it.

    Returns:
        The canonical, stored form of the ticker.
    """
    return symbol.strip().upper()


__all__ = ["SYMBOL_PATTERN", "normalize_symbol"]
