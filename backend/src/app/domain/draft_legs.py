"""The legs of a draft order, as the one string a caller sends back (spec 0031).

A multi-leg order is edited leg by leg, and every edit has to travel as a
**declared option** (ADR-K D-3): one bounded string, ``NVDA:3,AVGO:2,AMD:14``,
rather than one option per ticker — seventeen optional integers would make
most combinations illegal states and would put the reference list into the
options schema a second time (spec 0031 OD-2).

The stepper the design draws is the reason this module also *writes* the
string. A client may not add one to a share count (N-2), so each rendered leg
carries the whole option value a ``+`` or a ``-`` sends — composed here, from
the same parser and the same bound the options model enforces.

Whole shares only. The design steps in units of one, and a fractional leg has
no stepper to draw it.
"""

from dataclasses import dataclass, replace
from typing import Final

from app.domain.errors import SymbolNotFoundError
from app.domain.market import market_asset

#: The most legs one draft carries. Five is two more than the design draws
#: and one more than its chips propose (`Add TSM`).
MAX_LEGS: Final[int] = 5
#: Six digits of shares: nothing in this portfolio is priced so low that a
#: seventh digit is an order anyone would draft.
MAX_LEG_QUANTITY: Final[int] = 999_999
#: The **whole** truth about what ``legs`` accepts, published to the model and
#: enforced by the options model from this one literal: ``TICKER:SHARES``
#: pairs, comma-separated, one to ``MAX_LEGS`` of them.
LEGS_PATTERN: Final[str] = r"^[A-Z]{2,10}:[0-9]{1,6}(,[A-Z]{2,10}:[0-9]{1,6}){0,4}$"
#: Five legs of a ten-letter ticker and six digits, with their separators.
MAX_LEGS_TEXT: Final[int] = MAX_LEGS * 17 + (MAX_LEGS - 1)

LEG_SEPARATOR: Final[str] = ","
QUANTITY_SEPARATOR: Final[str] = ":"


@dataclass(frozen=True, slots=True)
class LegRequest:
    """One leg as asked for: a ticker and a whole number of shares."""

    symbol: str
    quantity: int


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
        legs.append(LegRequest(symbol=symbol, quantity=int(quantity)))
    return tuple(legs)


def format_legs(legs: tuple[LegRequest, ...]) -> str:
    """Write requests back as the option value a caller sends."""
    return LEG_SEPARATOR.join(
        f"{leg.symbol}{QUANTITY_SEPARATOR}{leg.quantity}" for leg in legs
    )


def with_quantity(
    legs: tuple[LegRequest, ...], symbol: str, quantity: int
) -> tuple[LegRequest, ...]:
    """Return ``legs`` with one leg's share count replaced, order kept."""
    return tuple(
        replace(leg, quantity=quantity) if leg.symbol == symbol else leg for leg in legs
    )


def stepped(legs: tuple[LegRequest, ...], symbol: str, step: int) -> str | None:
    """Return the option value one stepper tap on ``symbol`` sends.

    Args:
        legs: The legs as rendered.
        symbol: The leg being stepped.
        step: ``+1`` or ``-1``.

    Returns:
        The whole ``legs`` string with that leg moved by ``step``, or ``None``
        when the move would leave the published bound — the client disables
        the control rather than sending a value the backend refuses.
    """
    current = next(leg.quantity for leg in legs if leg.symbol == symbol)
    target = current + step
    if target < 0 or target > MAX_LEG_QUANTITY:
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
