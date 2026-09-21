"""The "when the agent picks this" section of the frozen contract (spec 0023).

A module beside ``catalog_actions`` for the same reason that one sits beside
``catalog_tables``: it answers a different question — *when does the model
reach for this surface* rather than *what does it show* or *what may it send
back* — and the files it would otherwise join are at the budget.

Prose, not a table. The pair is two sentences a designer wrote and a model
reads; a two-row table would add borders to a paragraph and make it harder to
compare with the design page it came from.
"""

from typing import Final

from app.presentation.guidance import Guidance

#: Printed where design has written no do/don't pair. It names the gap rather
#: than leaving the heading empty, because an empty section reads like an
#: oversight while this is a recorded state: the component's design page has
#: not been exported, so the catalog has nothing to publish and says so.
NO_GUIDANCE: Final[str] = (
    "_No design page for this component yet, so the catalog teaches the model "
    "only this view's summary and its options. It is not guidance this "
    "backend may invent._"
)


def guidance_note(guidance: Guidance | None) -> str:
    """Render the do/don't pair, or say that design has not written one.

    Args:
        guidance: The projection's declared guidance, if design wrote one.

    Returns:
        Two Markdown bullets — the question this view answers and the one it
        does not — or ``NO_GUIDANCE``.
    """
    if guidance is None:
        return NO_GUIDANCE
    return (
        f"- **Use it when** {guidance.use_when}\n"
        f"- **Do not use it for** {guidance.avoid_when}"
    )


__all__ = ["NO_GUIDANCE", "guidance_note"]
