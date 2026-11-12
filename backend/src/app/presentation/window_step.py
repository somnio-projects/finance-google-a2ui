"""One step of ``attribution.window.v1`` — a holding's move over a window.

The step is its own type. Reusing the waterfall's ``HoldingStep`` was tried
and pydantic refused it, correctly: that step carries ``units`` (a quantity)
and ``price`` (a unit price), which a window contribution does not have — it
has a value when the window opened and a value now. Bending money into a
field typed as a quantity to save a class is exactly the kind of "nearly the
same" that makes a contract unreadable. Split out of ``window_payload`` under
the 150-line budget (spec 0056).
"""

from pydantic import Field

from app.presentation.fragments import Bucket, MoneyDisplay, PercentageDisplay


class WindowStep(Bucket):
    """One holding's contribution to the move, with what its tooltip shows.

    ``Bucket`` stays the generic primitive — a step of any walk. A window's
    step knows more: how far the holding itself moved over the window, and
    between which two values.
    """

    move: PercentageDisplay = Field(
        description="The holding's own signed move over the window."
    )
    opened: MoneyDisplay = Field(
        description="What the position was worth when the window opened."
    )
    closed: MoneyDisplay = Field(description="What it is worth now.")
    detail: str = Field(
        max_length=64,
        description="The selected state's sentence, written here.",
        examples=["+4.2% · $104,049.00 → $108,419.40"],
    )
    delta_label: str = Field(
        max_length=32,
        description="The caption printed in front of `delta` (GGU-119 BG-1).",
        examples=["Contribution"],
    )


__all__ = ["WindowStep"]
