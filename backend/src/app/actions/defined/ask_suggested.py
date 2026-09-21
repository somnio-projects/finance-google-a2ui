"""``ask.suggested.v1`` — tapping an entry chip starts a turn (GGU-32).

A chip is a user turn nobody typed, so it cannot be an option: there is no
view to re-render. What it *is* is a selection from a curated table — the
client sends a registered key and the turn receives that key's registered
text, byte for byte (spec 0022 AC-8).

**The client cannot send prompt text through this path at all.** The only
argument is a key the ``Literal`` admits; the sentence comes from
``app.actions.suggestions`` and from nowhere else.
"""

from typing import Final

from pydantic import Field

from app.actions.contracts import ActionArgs
from app.actions.registry import register
from app.actions.spec import SurfaceActionSpec
from app.actions.suggestions import SuggestionKey, suggestion_prompt

ACTION_ID: Final[str] = "ask.suggested.v1"
LABEL: Final[str] = "Ask a suggested question"


class AskSuggestedArgs(ActionArgs):
    """The one argument a chip carries: which registered suggestion it is."""

    suggestion: SuggestionKey = Field(
        default="why-did-i-move",
        description="Registered suggestion key whose prompt the turn runs.",
        examples=["biggest-drivers"],
    )


def compose(args: AskSuggestedArgs) -> str:
    """Return the registered prompt for ``args.suggestion``, verbatim."""
    return suggestion_prompt(args.suggestion)


ACTION: Final = register(
    SurfaceActionSpec(
        id=ACTION_ID,
        label=LABEL,
        args=AskSuggestedArgs,
        prompt=compose,
    )
)

__all__ = ["ACTION", "ACTION_ID", "LABEL", "AskSuggestedArgs", "compose"]
