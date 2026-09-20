"""Short/long-term classification of a tax lot (spec 0003 AC-3, OD-4).

**The boundary rule:** a lot is **long-term** when it has been held for
**strictly more than 365 days** — ``(as_of - acquired_on).days > 365``. Exactly
365 days is **short**-term, so the calendar anniversary of a purchase is still
short-term and the day after it is long-term.

The rule counts calendar days, which makes the leap year explicit instead of
implicit: a lot acquired on 2024-02-29 and read on 2025-02-28 has been held 365
days and is therefore short-term.

``as_of`` is injected and fixed at seed time (ADR-F D-6) so a lot sitting on
the boundary cannot flip term between two questions in the same demo.
"""

from datetime import date
from enum import StrEnum
from typing import Final

from app.domain.errors import PortfolioInvariantError

LONG_TERM_DAYS: Final[int] = 365


class LotTerm(StrEnum):
    """Holding-period classification of a tax lot."""

    SHORT = "short"
    LONG = "long"


def holding_period_days(acquired_on: date, *, as_of: date) -> int:
    """Return how many calendar days the lot has been held at ``as_of``.

    Args:
        acquired_on: The day the lot was acquired.
        as_of: The instant the portfolio is read at, as a date.

    Returns:
        The non-negative number of days held.

    Raises:
        PortfolioInvariantError: When the lot was acquired after ``as_of``.
    """
    days = (as_of - acquired_on).days
    if days < 0:
        msg = (
            f"lot acquired {acquired_on.isoformat()} is in the future "
            f"at as_of {as_of.isoformat()}"
        )
        raise PortfolioInvariantError(msg)
    return days


def derive_term(acquired_on: date, *, as_of: date) -> LotTerm:
    """Classify the lot as short- or long-term at ``as_of``.

    Args:
        acquired_on: The day the lot was acquired.
        as_of: The instant the portfolio is read at, as a date.

    Returns:
        ``LotTerm.LONG`` beyond 365 days held, ``LotTerm.SHORT`` otherwise.
    """
    held = holding_period_days(acquired_on, as_of=as_of)
    return LotTerm.LONG if held > LONG_TERM_DAYS else LotTerm.SHORT


__all__ = ["LONG_TERM_DAYS", "LotTerm", "derive_term", "holding_period_days"]
