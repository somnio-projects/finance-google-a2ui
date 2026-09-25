"""How long a lot has been held, written for a reader (spec 0049 OD-2).

Separate from ``app.core.display`` for the reason ``trend`` is: that module
turns a ``Decimal`` into money, a quantity or a percentage, and this turns a
**count of days** into a duration. No currency, no locale, no precision option
— a duration is one string with one rule.

**Two forms, and the threshold is not invented.** It is ``LONG_TERM_DAYS``, the
365-day boundary the tax rule already draws (``app.domain.terms``), which is
the only thing the column this string lands in is trying to communicate. So the
duration and the short/long pill beside it cannot contradict each other: they
read the same comparison.

The boundary is stated where it is, not imported from ``domain`` — ``core`` may
not depend on ``domain`` (`architecture.md`) — and
``tests/unit/core/test_period_display.py`` asserts the two constants are equal
rather than trusting this sentence, which is the failure mode
`ci-conventions.md` §5 keeps finding.

**The units and the rounding are read off the artboard, not chosen here.** The
first draft printed days below the boundary (``363 d``); the UI Kit frame
(`specs/frontend/assets/0027-taxlot-uikit/`) prints **months** — ``8 mo``,
``4 mo`` beside ``5.5 yr`` and ``4.1 yr`` — and it also settles the rounding,
which a description of the rule would not have. Its *Jan 15, 2026* lot reads
``8 mo`` at an ``as_of`` of roughly 2026-09-09, which is 7.8 average months:
truncation gives ``7 mo`` and only rounding gives the string the designer
drew.
"""

from decimal import Decimal
from typing import Final

from app.core.locales import quantize

#: The short/long boundary, in days. Must equal ``app.domain.terms``'s
#: ``LONG_TERM_DAYS``; a test compares them.
LONG_TERM_DAYS: Final[int] = 365

#: Average calendar year, so a leap day does not move a figure a reader would
#: otherwise see move.
DAYS_PER_YEAR: Final[Decimal] = Decimal("365.25")

MONTHS_PER_YEAR: Final[int] = 12

YEAR_PRECISION: Final[int] = 1
MONTH_PRECISION: Final[int] = 0

MONTH_UNIT: Final[str] = "mo"
YEAR_UNIT: Final[str] = "yr"


def holding_period_display(days: int) -> str:
    """Return how long a lot has been held, as the cell prints it.

    Args:
        days: Calendar days held, as ``holding_period_days`` counted them.

    Returns:
        ``"8 mo"`` at or below the long-term boundary, ``"5.5 yr"`` above it.
        At exactly 365 days — still short-term — the months form wins, so the
        string and the term pill always agree.

    Raises:
        ValueError: When ``days`` is negative. The domain refuses a lot dated
            after ``as_of`` before this is reached, so a negative here means a
            caller did its own arithmetic, which is worth a loud failure
            rather than a plausible ``"-1 mo"``.
    """
    if days < 0:
        msg = f"a lot cannot be held for {days} days"
        raise ValueError(msg)
    years = Decimal(days) / DAYS_PER_YEAR
    if days <= LONG_TERM_DAYS:
        months = quantize(years * MONTHS_PER_YEAR, precision=MONTH_PRECISION)
        return f"{months} {MONTH_UNIT}"
    return f"{quantize(years, precision=YEAR_PRECISION)} {YEAR_UNIT}"


__all__ = [
    "DAYS_PER_YEAR",
    "LONG_TERM_DAYS",
    "MONTHS_PER_YEAR",
    "MONTH_PRECISION",
    "MONTH_UNIT",
    "YEAR_PRECISION",
    "YEAR_UNIT",
    "holding_period_display",
]
