"""What the model is taught about ``scenario.comparison.v1`` (GGU-53).

A module of its own, like every view's guidance: this is **design-owned
prose**, taken from the design catalog's Zone 3, and a designer editing the
sentence the model is taught should not have to read a projection to find it.
The 150-line budget makes the same choice for the views that are already at
it.

One change from the designer's wording, recorded in spec 0023 §4: the page
says to mark at most one scenario ``recommended``, and this card has no such
field — spec 0017 OD-4 decided it ranks nothing, names the spread and lets the
reader choose. The guidance therefore teaches the rule this backend actually
enforces rather than one the payload cannot express.
"""

from typing import Final

from app.presentation.guidance import Guidance

GUIDANCE: Final[Guidance] = Guidance(
    use_when=(
        "the user faces a choice between strategies and the decision hinges "
        "on comparing the same metrics across them — which lots to sell, "
        "selling now or waiting. Every column's figures come from this "
        "render; never fabricate the comparison."
    ),
    avoid_when=(
        "a single option, where there is nothing to compare — "
        "`taxlots.table.v1` shows one sale in detail. Do not rank or bold the "
        "values in prose: this card names the spread and recommends no method."
    ),
)

__all__ = ["GUIDANCE"]
