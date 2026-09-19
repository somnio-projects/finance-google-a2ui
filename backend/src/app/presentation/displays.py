"""Figure/string pairs — the only shape a number reaches the client in.

ADR-K D-5: every number in a projection is a **pre-formatted string**, and the
exact ``Decimal`` may travel next to it for charting, never instead of it. The
pair is what lets the widget plot an exact value and print a correctly rounded
one without doing either job itself.

Re-exported from ``app.presentation.fragments``, so a projection imports the
whole vocabulary from one place.
"""

from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.presentation.formatting import (
    DEFAULT_LOCALE,
    MONEY_PRECISION,
    PERCENTAGE_PRECISION,
    money_display,
    percentage_display,
)


class MoneyDisplay(BaseModel):
    """A monetary figure: the exact amount and the string to render."""

    model_config = ConfigDict(frozen=True)

    amount: Decimal = Field(
        description="Exact, unrounded amount — for charting, never for display.",
        examples=["26985.00"],
    )
    display: str = Field(
        max_length=32,
        description="Pre-formatted amount the client binds as-is.",
        examples=["$26,985.00"],
    )


class PercentageDisplay(BaseModel):
    """A ratio: the exact ``0..1`` value and the percentage string to render."""

    model_config = ConfigDict(frozen=True)

    value: Decimal = Field(
        description="Exact ratio between 0 and 1 — for charting.",
        examples=["0.3124"],
    )
    display: str = Field(
        max_length=16,
        description="Pre-formatted percentage the client binds as-is.",
        examples=["31.24%"],
    )


def money(
    value: Decimal, *, precision: int = MONEY_PRECISION, locale: str = DEFAULT_LOCALE
) -> MoneyDisplay:
    """Pair an exact amount with its formatted string.

    Args:
        value: The exact amount the domain computed.
        precision: Decimal places to show.
        locale: Which separators and currency placement to use.

    Returns:
        The pair a widget binds.
    """
    return MoneyDisplay(
        amount=value, display=money_display(value, precision=precision, locale=locale)
    )


def percentage(
    value: Decimal,
    *,
    precision: int = PERCENTAGE_PRECISION,
    locale: str = DEFAULT_LOCALE,
) -> PercentageDisplay:
    """Pair an exact ``0..1`` ratio with its formatted percentage string.

    Args:
        value: The exact ratio the domain computed.
        precision: Decimal places to show.
        locale: Which separators to use.

    Returns:
        The pair a widget binds.
    """
    return PercentageDisplay(
        value=value,
        display=percentage_display(value, precision=precision, locale=locale),
    )


__all__ = ["MoneyDisplay", "PercentageDisplay", "money", "percentage"]
