"""The DTO of ``attribution.window.v1`` — what moved the portfolio, over a window.

**Why this is not ``attribution.waterfall.v1`` with an option.** That
projection is *unrealised P/L, walked*: it compares every holding to what it
**cost**. This one compares it to what it was **worth at the start of a
window**. `domain/attribution.py` opens by saying they are different
questions; the presentation layer had only the first, so the agent's
``compute_attribution`` tool — which computes a window — attached a surface
drawing the other quantity. The reader saw a sentence about today beside a
chart about all time, and in the worst case the *same holding* named as the
biggest loss in words and the biggest gain in bars.

Versioning the existing view instead was rejected: `/v1` is a contract and a
client may still ask for the all-time walk, which remains the right answer to
*"how much am I up on each holding?"*. Two questions, two ids.

The A2UI **component name is the same** ``AttributionWaterfall``: this is the
design's waterfall drawing a different quantity, not a second widget, so the
client binds it by adding a registration and no new painter.

The **step, however, is its own type**. Reusing the waterfall's ``HoldingStep``
was tried and pydantic refused it, correctly: that step carries ``units`` (a
quantity) and ``price`` (a unit price), which a window contribution does not
have — it has a value when the window opened and a value now. Bending money
into a field typed as a quantity to save a class is exactly the kind of
"nearly the same" that makes a contract unreadable.
"""

from typing import Final, Literal

from pydantic import Field

from app.presentation.fragments import (
    Annotation,
    Bucket,
    Delta,
    MoneyDisplay,
    PercentageDisplay,
    ProjectionDto,
    Total,
)

VIEW_ID: Final[str] = "attribution.window.v1"

#: The windows a caller may ask for, and the words each one is titled with.
#: The same closed set the agent's tool accepts — one declaration, imported by
#: the tool, so the model and the endpoint cannot drift apart.
WINDOW_DAYS: Final[dict[str, int]] = {"1d": 1, "7d": 7, "30d": 30}
WINDOW_WORDS: Final[dict[str, str]] = {
    "1d": "today",
    "7d": "over the last week",
    "30d": "over the last 30 days",
}
DEFAULT_WINDOW: Final[str] = "1d"

#: The title names the window, because a walk with no period on it is the
#: defect this view exists to close.
TITLE_PREFIX: Final[str] = "What moved your portfolio"
SUMMARY: Final[str] = (
    "The portfolio's move over a chosen window, one bucket per holding, "
    "biggest mover first. Not unrealised profit and loss: this compares each "
    "holding to what it was worth when the window opened, not to what it cost."
)
SECTIONS: Final[tuple[str, ...]] = ("buckets", "annotations")
NET_LABEL: Final[str] = "Net"
START_LABEL: Final[str] = "Window open"
END_LABEL: Final[str] = "Now"


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
    selected_label: str = Field(
        max_length=48,
        description="What the card's header says while this step is selected.",
        examples=["NVDA selected"],
    )


class AttributionWindowPayload(ProjectionDto):
    """The portfolio's move over one window, walked holding by holding."""

    view: Literal["attribution.window.v1"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    title: str = Field(
        max_length=120,
        description="Title the widget shows; it names the window.",
        examples=["What moved your portfolio today"],
    )
    window: Literal["1d", "7d", "30d"] = Field(
        description=(
            "The window this payload was computed over, echoed back. It is a "
            "payload field named exactly as the option that sets it, which is "
            "how the contract declares the control editable."
        ),
        examples=["1d"],
    )
    period: str = Field(
        max_length=40,
        description=(
            "The window in words, written here so the client never composes "
            "a phrase out of a code."
        ),
        examples=["today", "over the last week"],
    )
    start: Total = Field(description="What the portfolio was worth when it opened.")
    end: Total = Field(description="What it is worth now.")
    net: Delta = Field(
        description="The whole move in one signed figure — the headline pill."
    )
    buckets: tuple[WindowStep, ...] = Field(
        default=(), description="One step per holding, biggest absolute move first."
    )
    annotations: tuple[Annotation, ...] = Field(
        default=(), description="Sentences shown beside the chart, written here."
    )


__all__ = [
    "DEFAULT_WINDOW",
    "END_LABEL",
    "NET_LABEL",
    "SECTIONS",
    "START_LABEL",
    "SUMMARY",
    "TITLE_PREFIX",
    "VIEW_ID",
    "WINDOW_DAYS",
    "WINDOW_WORDS",
    "AttributionWindowPayload",
    "WindowStep",
]
