"""What ``payoff`` will accept: the bound table, in one readable place.

Spec 0014 §5 treats these as a **security property** — they are what makes the
largest answer the tool can be made to produce 51 points, whatever the model
asks for. A bound that shares a file with the model enforcing it is easy to
widen by accident while editing something else; here it is a table a reviewer
can read in one screen.

``payoff_order`` enforces them, ``payoff_rows`` renders the result and
``payoff`` is the tool.
"""

from typing import Final, Literal

from app.domain.payoff import Side

#: Digits, optionally a decimal point and up to eight places. No sign, no
#: exponent, no separators: a size is a plain positive amount, and anything
#: else is rejected by the schema rather than by an exception mid-curve.
SIZE_PATTERN: Final[str] = r"^\d{1,12}(\.\d{1,8})?$"
MAX_SIZE_TEXT: Final[int] = 21

SizeUnit = Literal["units", "usd"]
DEFAULT_SIZE_UNIT: Final[SizeUnit] = "units"
DEFAULT_SIDE: Final[Side] = "buy"

MIN_RANGE_PCT: Final[int] = 5
MAX_RANGE_PCT: Final[int] = 90
DEFAULT_RANGE_PCT: Final[int] = 30

#: 25 steps a side is 51 points — the largest curve any argument can ask for.
MAX_STEPS: Final[int] = 25
DEFAULT_STEPS: Final[int] = 12

__all__ = [
    "DEFAULT_RANGE_PCT",
    "DEFAULT_SIDE",
    "DEFAULT_SIZE_UNIT",
    "DEFAULT_STEPS",
    "MAX_RANGE_PCT",
    "MAX_SIZE_TEXT",
    "MAX_STEPS",
    "MIN_RANGE_PCT",
    "SIZE_PATTERN",
    "SizeUnit",
]
