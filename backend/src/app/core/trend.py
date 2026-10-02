"""Which way a figure points — the token a widget binds to pick a colour.

Separate from ``app.core.display`` because it answers a different question.
``display`` turns a ``Decimal`` into the text a human reads; this turns one
into a **direction**, which is a categorical answer with three values and no
locale, no precision and no currency.

It shares ``display``'s rounding rule, and must: a figure and the arrow beside
it are read as one statement, so they have to agree about what zero is.
"""

from decimal import Decimal
from typing import Final, Literal

from app.core.locales import quantize

#: The three answers, as a type. Until spec 0049 this module returned ``str``
#: for no better reason than that the literal lived in ``app.domain.day_change``
#: and ``core`` may not import ``domain``. Declaring it here is not a second
#: vocabulary: it is the same three tokens, and
#: ``tests/unit/core/test_trend.py`` asserts the two declarations are equal
#: rather than trusting this comment — the failure mode
#: `.claude/rules/ci-conventions.md` §5 keeps finding (spec 0049 OD-5).
Trend = Literal["up", "down", "flat"]

TREND_PRECISION: Final[int] = 2

UP: Final[Trend] = "up"
DOWN: Final[Trend] = "down"
FLAT: Final[Trend] = "flat"


def trend_of(value: Decimal, *, precision: int = TREND_PRECISION) -> Trend:
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


__all__ = ["DOWN", "FLAT", "TREND_PRECISION", "UP", "Trend", "trend_of"]
