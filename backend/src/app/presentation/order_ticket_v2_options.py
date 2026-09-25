"""The declared options of ``order.ticket.v2`` (spec 0031).

Two knobs beside the display trio: which way the order goes, and the legs as
one bounded string — ``BTC:0.06,ETH:1.0,SOL:16``. One string rather than one
option per ticker (spec 0031 OD-2): a stepper edit is then the same option
with one number moved, the bound is a single pattern the model and the widget
both read, and the reference list is not spelled into the schema a second
time. The pattern cannot say that a ticker exists or that a leg is not
repeated, so a validator says it — as the option's own error, so both callers
see a 422 naming ``legs`` (ADR-K D-3, D-11).

Its own module for the reason ``order_sizing`` is one: *what a caller may ask
for*, apart from *what is rendered*.
"""

from typing import Final

from pydantic import Field, field_validator

from app.domain.draft_legs import (
    LEGS_PATTERN,
    MAX_LEGS_TEXT,
    LegRequest,
    parse_legs,
)
from app.domain.payoff import Side
from app.presentation.options import DisplayOptions

#: What the ``majors`` basket composes for the design's own prompt,
#: *"put about $10k into the majors"*, at the seeded prices — a test compares
#: the two rather than a comment claiming they agree.
DEFAULT_LEGS: Final[str] = "BTC:0.06,ETH:1.0,SOL:16"


class OrderTicketV2Options(DisplayOptions):
    """Declared knobs of ``order.ticket.v2``; nothing else is accepted."""

    legs: str = Field(
        default=DEFAULT_LEGS,
        pattern=LEGS_PATTERN,
        max_length=MAX_LEGS_TEXT,
        description=(
            "The legs of the draft as `TICKER:UNITS` pairs separated by "
            "commas, one to five of them, units up to eight decimals, each "
            "ticker from the market reference and named once. Every rendered "
            "leg carries the value a `+` or `-` sends back, so a stepper edit "
            "is this option re-sent with one number moved by that asset's own "
            "step."
        ),
        examples=[DEFAULT_LEGS, "BTC:0.07,ETH:1.0,SOL:16"],
    )
    side: Side = Field(
        default="buy",
        description=(
            "Which way every leg goes. A `buy` draws on the portfolio's cash "
            "and is blocked when it would exceed it; a `sell` raises cash."
        ),
        examples=["buy"],
    )

    @field_validator("legs")
    @classmethod
    def _known_and_distinct(cls, value: str) -> str:
        """Reject a ticker outside the reference or a leg named twice.

        Args:
            value: The option as sent, already matching the pattern.

        Returns:
            The same value.

        Raises:
            ValueError: From ``parse_legs`` — pydantic reports it under the
                option's own name, which is what ``resolve.validated_options``
                turns into the 422 both callers receive.
        """
        parse_legs(value)
        return value

    def requests(self) -> tuple[LegRequest, ...]:
        """Return the legs this render was asked for, in the order written."""
        return parse_legs(self.legs)


__all__ = ["DEFAULT_LEGS", "OrderTicketV2Options"]
