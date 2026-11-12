"""``drill.attribution.v1`` — go deeper on one driver (GGU-31).

The interaction spec 0022 §0's rule sends here rather than to an option: the
answer is not the same chart with a different parameter, it is *the agent
recomposing at that depth* — new narration, possibly a different component, a
back affordance and a graceful leaf case. That is a turn (OD-7).

What the surface sends is a **symbol**, drawn from the curated market
reference and nothing else. What the turn receives is the sentence below, a
constant in this file with the validated symbol substituted in: the client
supplies a value, never the sentence, the tool or the view (ADR-K D-3).

**And the turn calls no model** (spec 0056). The tap already names the one
argument ``driver_detail`` takes, so the action pins that call: the tool runs,
its card is drawn, and the answer below is filled from the tool's own display
strings. Choosing the tool was the only step a model did here, and the only
one that was not deterministic.
"""

from collections.abc import Mapping
from typing import Final

from pydantic import Field

from app.actions.contracts import ActionArgs, DirectCall
from app.actions.registry import register
from app.actions.spec import SurfaceActionSpec
from app.domain.symbols import Symbol

ACTION_ID: Final[str] = "drill.attribution.v1"
LABEL: Final[str] = "Break this down"

#: The tool the drill pins. ``app.actions`` may not import ``app.agent``, so
#: the name is spelled here and a test compares it with the agent registry.
DRIVER_TOOL: Final[str] = "driver_detail"

#: What a held driver's turn says; every hole is a string the tool returned.
ANSWER: Final[str] = (
    "{name} ({symbol}) contributed {contributionDisplay} today: its price "
    "moved {priceMovePctDisplay} ({priceMoveDisplay}) on {sharesDisplay} "
    "units at {priceDisplay}, {shareOfDayDisplay} of the day's "
    "{dayGainDisplay}."
)
#: The leaf a drill can reach: a symbol the portfolio does not hold.
NOT_HELD: Final[str] = (
    "{symbol} is not held in this portfolio, so there is no contribution to break down."
)
#: What the turn says when the tool answered with an error marker instead.
UNAVAILABLE: Final[str] = "I couldn't break that holding down just now."

#: The drivers a drill may name: the curated market reference
#: (``app.domain.market``) spelled as a bound, the same way
#: ``OrderTicketOptions.symbol`` spells it. Two declarations of one fact, so a
#: test compares them instead of a comment claiming they agree (0022 AC-7).
Driver = Symbol


class DrillAttributionArgs(ActionArgs):
    """The one argument a drill takes; anything else is a rejection."""

    driver: Driver = Field(
        default="BTC",
        description="Asset to break down further, from the market reference.",
        examples=["LINK"],
    )


def compose(args: DrillAttributionArgs) -> str:
    """Return the turn's input for ``args`` — backend text, caller's value."""
    return (
        f"Break down the contribution of {args.driver} in more detail for the "
        "same window, and show the result."
    )


def narrate(result: Mapping[str, object]) -> str:
    """Return the drill turn's answer, copied from ``driver_detail``'s result.

    Args:
        result: The tool's payload as the turn received it.

    Returns:
        The held sentence, the not-held leaf, or :data:`UNAVAILABLE` when a
        hole has nothing to fill it — never a figure the tool did not return.
    """
    held = result.get("held")
    template = ANSWER if held is True else NOT_HELD if held is False else None
    words = {key: value for key, value in result.items() if isinstance(value, str)}
    try:
        return UNAVAILABLE if template is None else template.format_map(words)
    except KeyError:
        return UNAVAILABLE


def direct(args: DrillAttributionArgs) -> DirectCall:
    """Pin ``driver_detail`` for the validated driver (spec 0056 AC-4)."""
    return DirectCall(
        tool=DRIVER_TOOL, arguments={"symbol": args.driver}, answer=narrate
    )


ACTION: Final = register(
    SurfaceActionSpec(
        id=ACTION_ID,
        label=LABEL,
        args=DrillAttributionArgs,
        prompt=compose,
        direct=direct,
    )
)

__all__ = [
    "ACTION",
    "ACTION_ID",
    "ANSWER",
    "DRIVER_TOOL",
    "LABEL",
    "NOT_HELD",
    "UNAVAILABLE",
    "DrillAttributionArgs",
    "compose",
    "direct",
    "narrate",
]
