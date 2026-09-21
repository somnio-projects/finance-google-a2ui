"""Which way a figure points — the token a widget binds to pick a colour.

Separate from ``app.core.display`` because it answers a different question.
``display`` turns a ``Decimal`` into the text a human reads; this turns one
into a **direction**, which is a categorical answer with three values and no
locale, no precision and no currency.

It shares ``display``'s rounding rule, and must: a figure and the arrow beside
it are read as one statement, so they have to agree about what zero is.
"""

from decimal import Decimal
from typing import Final

from app.core.locales import quantize

TREND_PRECISION: Final[int] = 2

UP: Final[str] = "up"
DOWN: Final[str] = "down"
FLAT: Final[str] = "flat"


def trend_of(value: Decimal, *, precision: int = TREND_PRECISION) -> str:
    """Return the direction token for ``value``.

    Decided from the **rounded** figure, for the same reason
    ``signed_money_display`` signs from it: a loss of half a cent renders as
    ``"$0.00"``, and a red arrow beside a zero is a contradiction the reader
    has no way to resolve (spec 0011 AC-6).

    Args:
        value: The exact profit or loss the domain computed.
        precision: The decimal places the accompanying string will show.

    Returns:
        ``"up"``, ``"down"`` or ``"flat"``.
    """
    rounded = quantize(value, precision=precision)
    if rounded > 0:
        return UP
    if rounded < 0:
        return DOWN
    return FLAT


__all__ = ["DOWN", "FLAT", "TREND_PRECISION", "UP", "trend_of"]
