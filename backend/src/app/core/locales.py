"""How a number is written down in a locale — separators, rounding, sign.

Split out of ``app.core.display`` for one reason: *what kind of number this
is* (money, a percentage, a quantity) and *how digits are written in a place*
are different questions, and keeping both in one module put it over the
150-line budget.

Locale is a declared, bounded option, not a machine setting: ``babel`` would
drag a data dependency and a system locale into a pure layer for three
separators, so the three the demo speaks are a small table instead.
"""

from decimal import ROUND_HALF_EVEN, Decimal
from typing import Final

DEFAULT_LOCALE: Final[str] = "en-US"

#: locale → (group separator, decimal separator, money template).
LOCALE_FORMATS: Final[dict[str, tuple[str, str, str]]] = {
    "en-US": (",", ".", "${amount}"),
    "es-AR": (".", ",", "US$ {amount}"),
    "de-DE": (".", ",", "{amount} $"),
}


def quantize(value: Decimal, *, precision: int) -> Decimal:
    """Return ``value`` rounded half-even to ``precision`` decimal places.

    Args:
        value: The exact amount computed by the domain.
        precision: Decimal places to keep.

    Returns:
        The rounded amount — display only, never fed back into arithmetic
        (ADR-E D-3).
    """
    return value.quantize(Decimal(1).scaleb(-precision), rounding=ROUND_HALF_EVEN)


def grouped_digits(value: Decimal, *, precision: int, locale: str) -> str:
    """Return a non-negative, already-rounded ``value`` with locale separators.

    Args:
        value: A non-negative amount, already at ``precision``.
        precision: Decimal places to render.
        locale: One of ``LOCALE_FORMATS``.

    Returns:
        The digits alone — ``"18,060.00"`` or ``"18.060,00"`` — with no
        currency mark and no sign.
    """
    group, point, _ = LOCALE_FORMATS[locale]
    whole, _, fraction = f"{value:,.{precision}f}".partition(".")
    grouped = whole.replace(",", group)
    if not fraction:
        return grouped
    return f"{grouped}{point}{fraction}"


def split_sign(value: Decimal, *, precision: int, locale: str) -> tuple[str, str]:
    """Return the sign and the grouped digits of ``value`` at ``precision``.

    Args:
        value: The exact amount.
        precision: Decimal places to render.
        locale: One of ``LOCALE_FORMATS``.

    Returns:
        ``("-", "1,234.56")`` for a negative amount, ``("", "…")`` otherwise.
        The sign is returned separately so each caller decides where it goes.
    """
    rounded = quantize(value, precision=precision)
    sign = "-" if rounded < 0 else ""
    return sign, grouped_digits(abs(rounded), precision=precision, locale=locale)


__all__ = [
    "DEFAULT_LOCALE",
    "LOCALE_FORMATS",
    "grouped_digits",
    "quantize",
    "split_sign",
]
