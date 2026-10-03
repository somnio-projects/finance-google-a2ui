"""The legs of a draft order, as the one string a caller sends back (spec 0031).

A multi-leg order is edited leg by leg, and every edit has to travel as a
**declared option** (ADR-K D-3): one bounded string, ``BTC:0.06,ETH:1.0,SOL:16``,
rather than one option per ticker — one optional decimal per asset would make
most combinations illegal states and would put the reference list into the
options schema a second time (spec 0031 OD-2).

The stepper the design draws is the reason this module also *writes* the
string. A client may not add to a unit count (N-2), so each rendered leg
carries the whole option value a ``+`` or a ``-`` sends — composed here, from
the same parser and the same bound the options model enforces.

**Fractional units, stepped by the asset's own step (spec 0044 OD-6).** The
legs were whole shares while the portfolio was equities. One whole unit of BTC
is a third of this portfolio, so a stepper that moved by one would take a
$9,773 draft past its cash on a single tap, and a basket that floored to one
would compose a leg of **zero**. The digits a leg may carry are therefore the
same as an order ticket's ``size`` — nine integers and eight decimals — and how
far one tap moves is a property of the asset, read from the market reference.
"""

from dataclasses import dataclass, replace
from decimal import Decimal
from typing import Final

from app.domain.errors import SymbolNotFoundError
from app.domain.market import market_asset
from app.domain.money import ZERO
from app.domain.orders import floor_to_step

#: The most legs one draft carries. Five is two more than the design draws
#: and one more than its chips propose (`Add LINK`).
MAX_LEGS: Final[int] = 5
#: Nine integer digits of units: a token quoted in fractions of a cent is still
#: not one anybody drafts a ten-digit order in.
MAX_LEG_QUANTITY: Final[Decimal] = Decimal("999999999")
#: One quantity, spelled once: nine integer digits and up to eight decimals,
#: the same shape ``presentation.order_sizing.SIZE_PATTERN`` publishes for a
#: single-leg ticket. Two spellings of "a quantity" is where they drift.
_QUANTITY_DIGITS: Final[str] = r"[0-9]{1,9}(\.[0-9]{1,8})?"
_LEG: Final[str] = rf"[A-Z]{{2,10}}:{_QUANTITY_DIGITS}"
#: The **whole** truth about what ``legs`` accepts, published to the model and
#: enforced by the options model from this one literal: ``TICKER:UNITS``
#: pairs, comma-separated, one to ``MAX_LEGS`` of them.
LEGS_PATTERN: Final[str] = rf"^{_LEG}(,{_LEG}){{0,{MAX_LEGS - 1}}}$"
#: Five legs of a ten-letter ticker and eighteen quantity characters, with
#: their separators.
MAX_LEGS_TEXT: Final[int] = MAX_LEGS * 29 + (MAX_LEGS - 1)

LEG_SEPARATOR: Final[str] = ","
QUANTITY_SEPARATOR: Final[str] = ":"


@dataclass(frozen=True, slots=True)
class LegRequest:
    """One leg as asked for: a ticker and an exact number of units."""

    symbol: str
    quantity: Decimal


def parse_legs(text: str) -> tuple[LegRequest, ...]:
    """Read ``legs`` into requests, rejecting what the pattern cannot.

    Args:
        text: A value already matching ``LEGS_PATTERN``.

    Returns:
        The legs in the order written, so the ticket lays them out as asked.

    Raises:
        ValueError: When a ticker is not in the market reference or appears
            twice — the two facts a regular expression cannot state. A
            ``ValueError`` so pydantic reports it as the option's own error.
    """
    legs: list[LegRequest] = []
    seen: set[str] = set()
    for item in text.split(LEG_SEPARATOR):
        symbol, _, quantity = item.partition(QUANTITY_SEPARATOR)
        if symbol in seen:
            msg = f"leg {symbol!r} appears more than once"
            raise ValueError(msg)
        try:
            market_asset(symbol)
        except SymbolNotFoundError as exc:
            msg = f"leg {symbol!r} is not in the market reference"
            raise ValueError(msg) from exc
        seen.add(symbol)
        legs.append(LegRequest(symbol=symbol, quantity=Decimal(quantity)))
    return tuple(legs)


def format_legs(legs: tuple[LegRequest, ...]) -> str:
    """Write requests back as the option value a caller sends."""
    return LEG_SEPARATOR.join(
        f"{leg.symbol}{QUANTITY_SEPARATOR}{leg.quantity}" for leg in legs
    )


def with_quantity(
    legs: tuple[LegRequest, ...], symbol: str, quantity: Decimal
) -> tuple[LegRequest, ...]:
    """Return ``legs`` with one leg's unit count replaced, order kept."""
    return tuple(
        replace(leg, quantity=quantity) if leg.symbol == symbol else leg for leg in legs
    )


def stepped(legs: tuple[LegRequest, ...], symbol: str, direction: int) -> str | None:
    """Return the option value one stepper tap on ``symbol`` sends.

    Args:
        legs: The legs as rendered.
        symbol: The leg being stepped.
        direction: ``+1`` or ``-1``. How far that is in units comes from the
            asset's own ``step``, not from the caller — the client may not
            derive it (N-2) and one step cannot serve BTC and ARB alike.

    Returns:
        The whole ``legs`` string with that leg moved by one step, or ``None``
        when the move would leave the published bound — the client disables
        the control rather than sending a value the backend refuses.
    """
    current = next(leg.quantity for leg in legs if leg.symbol == symbol)
    step = market_asset(symbol).step
    # Onto the asset's grid first (GGU-149): after a drag `current` is a
    # rebalanced, off-grid quantity, and adding a step to it skipped around.
    # `+` is the next grid point up, `-` the floor or the point below it.
    floor = floor_to_step(current, step=step)
    if direction > 0:
        target = floor + step
    else:
        target = floor - step if floor == current else floor
    if target < ZERO or target > MAX_LEG_QUANTITY:
        return None
    return format_legs(with_quantity(legs, symbol, target))


__all__ = [
    "LEGS_PATTERN",
    "MAX_LEGS",
    "MAX_LEGS_TEXT",
    "MAX_LEG_QUANTITY",
    "LegRequest",
    "format_legs",
    "parse_legs",
    "stepped",
    "with_quantity",
]
