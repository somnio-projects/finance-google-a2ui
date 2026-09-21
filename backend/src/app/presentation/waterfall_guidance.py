"""What the model is taught about ``attribution.waterfall.v1`` (GGU-53).

Here rather than in ``views/attribution_waterfall.py`` for the reason
``attribution_walk`` is here: that module is at the 150-line budget, and the
budget is a gate while "one module per view" is a preference
(`.claude/rules/backend/presentation.md` §1). It cannot live *inside*
``views/`` either — every module in that package is imported as a registered
view (``views/__init__.py``), so a helper dropped there would be discovered as
a projection that never registers.

The wording is the design catalog's own, from the Attribution Waterfall detail
page's Zone 3, rewritten only where it named things this backend does not
have: the designer's ``HoldingsSummary`` is our ``holdings.allocation.v1``,
and ``compute_attribution()`` is not a tool this host registers, so the
sentence points at the rule instead of at a function that would 404.
"""

from typing import Final

from app.presentation.guidance import Guidance

GUIDANCE: Final[Guidance] = Guidance(
    use_when=(
        "the user asks WHY a value changed and the answer decomposes into "
        "signed contributions that sum to a net delta — what drove the "
        "portfolio's result, profit and loss by position. The steps arrive "
        "largest move first; do not reorder them."
    ),
    avoid_when=(
        "a static breakdown of what is held now — `holdings.allocation.v1` "
        "answers that. Never write the figures yourself: render this view and "
        "copy the `display` strings it returns."
    ),
)

__all__ = ["GUIDANCE"]
