"""The ADR-E display pairs an order ticket writes down.

Split out of ``tickets.py`` when `hint` pushed that module past the 150-line
budget. The split is along the seam the module already had: what a *field*
declares (``TicketInput``) versus how a *figure* is written down. The budget
is a gate and "one module" is a preference — the rule this repository wrote
for `presentation/views/` applies one directory up.
"""

from decimal import Decimal

from pydantic import BaseModel, ConfigDict, Field

from app.core.display import price_display, quantity_display
from app.core.locales import DEFAULT_LOCALE
from app.presentation.displays import MoneyDisplay


class QuantityDisplay(BaseModel):
    """A number of units: the exact figure and the string to render."""

    model_config = ConfigDict(frozen=True)

    units: Decimal = Field(
        description="Exact, unrounded unit count — for arithmetic, not display.",
        examples=["3.2808399"],
    )
    display: str = Field(
        max_length=32,
        description="Pre-formatted unit count the client binds as-is.",
        examples=["3.2808399"],
    )


def quantity(value: Decimal, *, locale: str = DEFAULT_LOCALE) -> QuantityDisplay:
    """Pair an exact unit count with its trimmed string, under ``locale``."""
    return QuantityDisplay(
        units=value, display=quantity_display(value, locale=locale, trim=True)
    )


def price(value: Decimal, *, locale: str = DEFAULT_LOCALE) -> MoneyDisplay:
    """Pair an exact unit price with the string a reader multiplies by.

    Quoted through ``price_display``, so a sub-dollar ticker prints no price
    its own notional contradicts (spec 0014 OD-10).
    """
    return MoneyDisplay(amount=value, display=price_display(value, locale=locale))


__all__ = ["QuantityDisplay", "price", "quantity"]
