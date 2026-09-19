"""The single ``Decimal`` → display-string boundary (ADR-E D-2, ADR-K D-5).

Every number a human or the model sees is formatted here, exactly once, so a
figure cannot be rendered two ways in one answer. ADR-E D-3 fixes the
rounding: ``ROUND_HALF_EVEN``, and **only at display** — never in intermediate
arithmetic. The exact ``Decimal`` travels next to the string it produced.

It lives in ``core`` because both ``app.agent`` (spec 0006) and
``app.presentation`` (spec 0005) need it and neither may import the other.
``app.core.locales`` holds the separators and the rounding it builds on.
"""

from decimal import Decimal
from typing import Final

from app.core.locales import (
    DEFAULT_LOCALE,
    LOCALE_FORMATS,
    quantize,
    split_sign,
)

MONEY_PRECISION: Final[int] = 2
QUANTITY_PRECISION: Final[int] = 8
PERCENTAGE_PRECISION: Final[int] = 2


def money_display(
    value: Decimal, *, precision: int = MONEY_PRECISION, locale: str = DEFAULT_LOCALE
) -> str:
    """Return ``value`` as the money string a widget or the model binds.

    Args:
        value: The exact amount, in the portfolio's currency.
        precision: Decimal places to show.
        locale: One of ``LOCALE_FORMATS``.

    Returns:
        ``"$18,060.00"`` or ``"-$1,234.56"`` — the sign leads the currency.
    """
    sign, digits = split_sign(value, precision=precision, locale=locale)
    return sign + LOCALE_FORMATS[locale][2].format(amount=digits)


def signed_money_display(
    value: Decimal, *, precision: int = MONEY_PRECISION, locale: str = DEFAULT_LOCALE
) -> str:
    """Return ``value`` as money with an explicit sign for gains and losses.

    Args:
        value: The exact amount, typically a profit or a loss.
        precision: Decimal places to show.
        locale: One of ``LOCALE_FORMATS``.

    Returns:
        ``"+$1,234.56"`` or ``"-$1,234.56"``; unsigned when it rounds flat,
        because ``"+$0.00"`` would claim a gain that is not there.
    """
    rendered = money_display(value, precision=precision, locale=locale)
    if quantize(value, precision=precision) > 0:
        return f"+{rendered}"
    return rendered


def percentage_display(
    value: Decimal,
    *,
    precision: int = PERCENTAGE_PRECISION,
    locale: str = DEFAULT_LOCALE,
) -> str:
    """Return a ``0..1`` ratio as the percentage string the caller binds.

    Args:
        value: The ratio the domain computed — ``0.3124``, not ``31.24``.
        precision: Decimal places to show.
        locale: One of ``LOCALE_FORMATS``.

    Returns:
        A percentage such as ``"31.24%"``.
    """
    sign, digits = split_sign(value * 100, precision=precision, locale=locale)
    return f"{sign}{digits}%"


def quantity_display(
    value: Decimal,
    *,
    precision: int = QUANTITY_PRECISION,
    locale: str = DEFAULT_LOCALE,
    trim: bool = False,
) -> str:
    """Return a unit count as the string the caller binds.

    Args:
        value: The exact number of units held or traded.
        precision: Decimal places — crypto quantities use 8 (ADR-E D-3).
        locale: One of ``LOCALE_FORMATS``.
        trim: Drop trailing zeros. A chart axis wants the fixed shape
            (``"0.60000000"``); a sentence the model reads aloud wants
            ``"0.6"``, so the caller says which it is.

    Returns:
        ``"0.60000000"``, or ``"0.6"`` when trimmed.
    """
    rounded = quantize(value, precision=precision)
    if trim:
        normalised = rounded.normalize()
        digits = f"{normalised:f}"
        return digits.replace(",", LOCALE_FORMATS[locale][0])
    sign, digits = split_sign(value, precision=precision, locale=locale)
    return sign + digits


__all__ = [
    "MONEY_PRECISION",
    "PERCENTAGE_PRECISION",
    "QUANTITY_PRECISION",
    "money_display",
    "percentage_display",
    "quantity_display",
    "signed_money_display",
]
