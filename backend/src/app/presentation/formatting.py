"""The one place a ``Decimal`` becomes a string (ADR-E D-2/D-3, ADR-K D-5).

The client never rounds, never formats and never computes a percentage, so
every number a projection emits passes through here exactly once. Rounding is
``ROUND_HALF_EVEN`` and happens **only** at display: the exact ``Decimal``
travels next to the string it produced, for charting.

Locale is a declared, bounded option rather than a machine setting: ``babel``
would drag a data dependency and a system locale into a pure layer for three
separators, so the three the demo speaks are a small table instead.
"""

from decimal import ROUND_HALF_EVEN, Decimal
from typing import Final

MONEY_PRECISION: Final[int] = 2
QUANTITY_PRECISION: Final[int] = 8
PERCENTAGE_PRECISION: Final[int] = 2
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
        The rounded amount — a display concern, never fed back into arithmetic.
    """
    return value.quantize(Decimal(1).scaleb(-precision), rounding=ROUND_HALF_EVEN)


def _digits(value: Decimal, *, precision: int, locale: str) -> str:
    """Return a non-negative, already-rounded ``value`` with locale separators."""
    group, point, _ = LOCALE_FORMATS[locale]
    whole, _, fraction = f"{value:,.{precision}f}".partition(".")
    grouped = whole.replace(",", group)
    if not fraction:
        return grouped
    return f"{grouped}{point}{fraction}"


def _signed(value: Decimal, *, precision: int, locale: str) -> tuple[str, str]:
    """Return the sign and the grouped digits of ``value`` at ``precision``."""
    rounded = quantize(value, precision=precision)
    sign = "-" if rounded < 0 else ""
    return sign, _digits(abs(rounded), precision=precision, locale=locale)


def money_display(
    value: Decimal, *, precision: int = MONEY_PRECISION, locale: str = DEFAULT_LOCALE
) -> str:
    """Return ``value`` as the money string the widget binds.

    Args:
        value: The exact amount, in the portfolio's currency.
        precision: Decimal places to show.
        locale: One of ``LOCALE_FORMATS``.

    Returns:
        A formatted amount such as ``$18,060.00`` or ``US$ 18.060,00``.
    """
    sign, digits = _signed(value, precision=precision, locale=locale)
    return sign + LOCALE_FORMATS[locale][2].format(amount=digits)


def percentage_display(
    value: Decimal,
    *,
    precision: int = PERCENTAGE_PRECISION,
    locale: str = DEFAULT_LOCALE,
) -> str:
    """Return a ``0..1`` ratio as the percentage string the widget binds.

    Args:
        value: The ratio the domain computed — ``0.3124``, not ``31.24``.
        precision: Decimal places to show.
        locale: One of ``LOCALE_FORMATS``.

    Returns:
        A formatted percentage such as ``31.24%``.
    """
    sign, digits = _signed(value * 100, precision=precision, locale=locale)
    return f"{sign}{digits}%"


def quantity_display(
    value: Decimal, *, precision: int = QUANTITY_PRECISION, locale: str = DEFAULT_LOCALE
) -> str:
    """Return a unit count as the string the widget binds.

    Args:
        value: The exact number of units held or traded.
        precision: Decimal places to show — crypto quantities use 8 (ADR-E D-3).
        locale: One of ``LOCALE_FORMATS``.

    Returns:
        A formatted quantity such as ``0.60000000``.
    """
    sign, digits = _signed(value, precision=precision, locale=locale)
    return sign + digits


__all__ = [
    "DEFAULT_LOCALE",
    "LOCALE_FORMATS",
    "MONEY_PRECISION",
    "PERCENTAGE_PRECISION",
    "QUANTITY_PRECISION",
    "money_display",
    "percentage_display",
    "quantity_display",
    "quantize",
]
