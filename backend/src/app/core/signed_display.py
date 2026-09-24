"""Signed displays — a *change* written down, as opposed to an amount.

Split from ``display.py`` when the second signed helper pushed it past the
150-line budget. The seam is real: every function in ``display.py`` renders a
quantity of something, and these two render how a quantity **moved**, which
is why they lead with a sign and why a flat move prints none — ``"+$0.00"``
would claim a gain that is not there.
"""

from decimal import Decimal

from app.core.display import (
    MONEY_PRECISION,
    PERCENTAGE_PRECISION,
    money_display,
    percentage_display,
)
from app.core.locales import DEFAULT_LOCALE, quantize


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


def signed_percentage_display(
    value: Decimal,
    *,
    precision: int = PERCENTAGE_PRECISION,
    locale: str = DEFAULT_LOCALE,
) -> str:
    """Return a ratio as a percentage with an explicit sign for a gain.

    The day-change figures the design draws read ``+0.68%`` and ``-2.3%``; a
    flat move reads ``0.0%`` rather than ``+0.0%``, for the reason
    ``signed_money_display`` gives.

    Args:
        value: The signed ratio — ``0.0068``, not ``0.68``.
        precision: Decimal places to show.
        locale: One of ``LOCALE_FORMATS``.

    Returns:
        ``"+0.68%"``, ``"-2.30%"`` or ``"0.00%"``.
    """
    rendered = percentage_display(value, precision=precision, locale=locale)
    if quantize(value * 100, precision=precision) > 0:
        return f"+{rendered}"
    return rendered


__all__ = ["signed_money_display", "signed_percentage_display"]
