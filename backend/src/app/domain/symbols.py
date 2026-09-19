"""Ticker-symbol shape shared by every entity in the portfolio domain.

Symbols are stored upper-case and matched after normalisation, so a caller may
ask for ``BTC``, ``btc`` or ``" btc "`` and get the same answer (spec 0003
AC-4).

Two shapes, for the two sides of that sentence: ``SYMBOL_PATTERN`` is the
**stored** form every entity validates against, and ``Ticker`` is the
**asked** form a tool accepts from the model before ``normalize_symbol`` folds
it. Both live here so a second caller cannot invent a third spelling of the
same rule (spec 0014 OD-13).
"""

from typing import Annotated, Final

from pydantic import StringConstraints

SYMBOL_PATTERN: Final[str] = r"^[A-Z]{2,10}$"

MAX_TICKER: Final[int] = 10
#: Case-insensitive twin of ``SYMBOL_PATTERN``: the stored form is upper-case,
#: but the model may ask in any case. Bounding the item matters as much as
#: bounding any list it sits in — twenty entries of five thousand characters
#: each is still unbounded input (spec 0011 §5).
TICKER_PATTERN: Final[str] = r"^[A-Za-z]{2,10}$"

Ticker = Annotated[
    str,
    StringConstraints(
        strip_whitespace=True, max_length=MAX_TICKER, pattern=TICKER_PATTERN
    ),
]


def normalize_symbol(symbol: str) -> str:
    """Return ``symbol`` stripped of whitespace and upper-cased.

    Args:
        symbol: A ticker as the caller typed it.

    Returns:
        The canonical, stored form of the ticker.
    """
    return symbol.strip().upper()


__all__ = [
    "MAX_TICKER",
    "SYMBOL_PATTERN",
    "TICKER_PATTERN",
    "Ticker",
    "normalize_symbol",
]
