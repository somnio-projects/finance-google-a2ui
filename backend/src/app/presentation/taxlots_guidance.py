"""What the model is taught about ``taxlots.table.v1`` (GGU-53).

A module of its own, like every view's guidance: this is **design-owned
prose**, taken from the design catalog's Tax-Lot Table page (Zone 3), and a
designer editing the sentence the model is taught should not have to read a
projection to find it.

Two changes from the designer's wording, recorded in spec 0023 §4. The page
names ``get_holdings()`` and ``simulate_sale()`` as the calls that fill the
table; ``simulate_sale`` is a real tool here but the lots are filled by
rendering this view, not by a second call, so the sentence points at the
render. And "never estimate tax rates in prose" is kept verbatim — it is the
numbers-from-tools invariant in the designer's own words, and this payload
deliberately stops at the realised split, before any rate.
"""

from typing import Final

from app.presentation.guidance import Guidance

GUIDANCE: Final[Guidance] = Guidance(
    use_when=(
        "the user asks about selling a position and the answer depends on "
        "WHICH lots go — the realised result always splits into its "
        "short-term and long-term halves, which is the point of the surface."
    ),
    avoid_when=(
        "comparing several lot-selection methods — `scenario.comparison.v1` "
        "puts those side by side. Never estimate a tax rate in prose: this "
        "view stops at the realised split, before any rate, fee or wash sale."
    ),
)

__all__ = ["GUIDANCE"]
