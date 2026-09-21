"""``drill.attribution.v1`` — go deeper on one driver (GGU-31).

The interaction spec 0022 §0's rule sends here rather than to an option: the
answer is not the same chart with a different parameter, it is *the agent
recomposing at that depth* — new narration, possibly a different component, a
back affordance and a graceful leaf case. That is a turn (OD-7).

What the surface sends is a **symbol**, drawn from the curated market
reference and nothing else. What the turn receives is the sentence below, a
constant in this file with the validated symbol substituted in: the client
supplies a value, never the sentence, the tool or the view (ADR-K D-3).
"""

from typing import Final

from pydantic import Field

from app.actions.contracts import ActionArgs
from app.actions.registry import register
from app.actions.spec import SurfaceActionSpec
from app.domain.symbols import Symbol

ACTION_ID: Final[str] = "drill.attribution.v1"
LABEL: Final[str] = "Break this down"

#: The drivers a drill may name: the curated market reference
#: (``app.domain.market``) spelled as a bound, the same way
#: ``OrderTicketOptions.symbol`` spells it. Two declarations of one fact, so a
#: test compares them instead of a comment claiming they agree (0022 AC-7).
Driver = Symbol


class DrillAttributionArgs(ActionArgs):
    """The one argument a drill takes; anything else is a rejection."""

    driver: Driver = Field(
        default="NVDA",
        description="Asset to break down further, from the market reference.",
        examples=["XOM"],
    )


def compose(args: DrillAttributionArgs) -> str:
    """Return the turn's input for ``args`` — backend text, caller's value."""
    return (
        f"Break down the contribution of {args.driver} in more detail for the "
        "same window, and show the result."
    )


ACTION: Final = register(
    SurfaceActionSpec(
        id=ACTION_ID,
        label=LABEL,
        args=DrillAttributionArgs,
        prompt=compose,
    )
)

__all__ = ["ACTION", "ACTION_ID", "LABEL", "DrillAttributionArgs", "compose"]
