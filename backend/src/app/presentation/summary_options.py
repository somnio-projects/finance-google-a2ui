"""What ``portfolio.summary.v1`` may be asked for (spec 0026 §4).

One knob of its own — ``range`` — beside the shared display options. The
range does **not** change the sparkline, which is always the last thirty
days (the design's own loading state says *"Loading last 30 days…"*); it
changes the period the headline delta is measured over and the word printed
beside it, ``today`` through ``all time``.
"""

from datetime import date
from typing import Final, Literal

from pydantic import Field

from app.domain.history import HISTORY_DAYS
from app.presentation.options import DisplayOptions

Range = Literal["1d", "1w", "1m", "ytd", "1y", "all"]

#: The word the hero prints after the delta, per range (the design's `today`).
PERIOD_LABELS: Final[dict[str, str]] = {
    "1d": "today",
    "1w": "this week",
    "1m": "this month",
    "ytd": "year to date",
    "1y": "past year",
    "all": "all time",
}

#: Points the sparkline carries whatever the range — the design's thirty days.
SPARK_POINTS: Final[int] = 30


class PortfolioSummaryOptions(DisplayOptions):
    """Declared knobs of ``portfolio.summary.v1``; nothing else is accepted."""

    range: Range = Field(
        default="1d",
        description=(
            "Period the headline change is measured over. `1d` compares to "
            "yesterday's close; the others to the portfolio's value that many "
            "days back, clamped to the depth of the generated history."
        ),
        examples=["1d"],
    )


def range_offset(selected: Range, *, as_of: date) -> int:
    """Return how many days back ``selected`` reaches from ``as_of``.

    Args:
        selected: The declared range.
        as_of: The day the portfolio is read at; needed for ``ytd``.

    Returns:
        A day count, at least ``1`` and never beyond the generated history.
    """
    days = {
        "1d": 1,
        "1w": 7,
        "1m": 30,
        "ytd": as_of.timetuple().tm_yday - 1,
        "1y": 365,
        "all": HISTORY_DAYS - 1,
    }[selected]
    return max(1, min(days, HISTORY_DAYS - 1))


__all__ = [
    "PERIOD_LABELS",
    "SPARK_POINTS",
    "PortfolioSummaryOptions",
    "Range",
    "range_offset",
]
