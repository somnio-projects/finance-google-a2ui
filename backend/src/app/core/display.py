"""The single ``Decimal`` → display-string boundary (ADR-E D-2, spec 0006 OD-5).

ADR-E D-3 fixes the rounding: USD to 2 dp, quantities to 8 dp, percentages to
2 dp, always ``ROUND_HALF_EVEN``, and **only here** — never in intermediate
arithmetic. Everything that shows a number to a human or to the model goes
through this module, so a figure cannot be formatted two different ways in one
answer.

It lives in ``core`` rather than in the agent or the presentation package
because both of them need it and neither may import the other.
"""

from decimal import ROUND_HALF_EVEN, Decimal
from typing import Final

USD_EXPONENT: Final[Decimal] = Decimal("0.01")
QUANTITY_EXPONENT: Final[Decimal] = Decimal("0.00000001")
PERCENT_EXPONENT: Final[Decimal] = Decimal("0.01")
_HUNDRED: Final[Decimal] = Decimal(100)


def _quantize(value: Decimal, exponent: Decimal) -> Decimal:
    """Round ``value`` to ``exponent`` with banker's rounding (ADR-E D-3)."""
    return value.quantize(exponent, rounding=ROUND_HALF_EVEN)


def money_display(amount: Decimal) -> str:
    """Render ``amount`` as USD with thousands separators.

    Args:
        amount: An exact monetary amount.

    Returns:
        ``"$64,250.00"`` for a positive amount, ``"-$64,250.00"`` for a
        negative one — the sign leads, so the currency stays readable.
    """
    rounded = _quantize(amount, USD_EXPONENT)
    sign = "-" if rounded < 0 else ""
    return f"{sign}${abs(rounded):,.2f}"


def signed_money_display(amount: Decimal) -> str:
    """Render ``amount`` as USD with an explicit sign for gains and losses.

    Args:
        amount: An exact monetary amount, typically a profit or loss.

    Returns:
        ``"+$1,234.56"``, ``"-$1,234.56"`` or ``"$0.00"`` when it rounds flat.
    """
    rounded = _quantize(amount, USD_EXPONENT)
    if rounded > 0:
        return f"+{money_display(rounded)}"
    return money_display(rounded)


def quantity_display(quantity: Decimal) -> str:
    """Render an asset quantity at 8 dp without trailing noise.

    Args:
        quantity: An exact number of units.

    Returns:
        ``"0.75"`` rather than ``"0.75000000"``; ``"0"`` for a flat zero.
    """
    rounded = _quantize(quantity, QUANTITY_EXPONENT).normalize()
    text = f"{rounded:f}"
    return text


def percent_display(ratio: Decimal) -> str:
    """Render a 0-to-1 ratio as a percentage at 2 dp.

    Args:
        ratio: A share of a whole, where ``Decimal("0.425")`` is 42.5 %.

    Returns:
        ``"42.50%"``.
    """
    return f"{_quantize(ratio * _HUNDRED, PERCENT_EXPONENT):.2f}%"


__all__ = [
    "PERCENT_EXPONENT",
    "QUANTITY_EXPONENT",
    "USD_EXPONENT",
    "money_display",
    "percent_display",
    "quantity_display",
    "signed_money_display",
]
