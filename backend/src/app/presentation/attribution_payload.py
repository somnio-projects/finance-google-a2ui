"""The DTO of ``attribution.waterfall.v1`` (spec 0005 AC-5, GGU-100).

Split from ``views/attribution_waterfall.py`` when the headline and the
per-step figures GGU-100 asks for pushed the view past the 150-line budget.
The seam is the one ``positions_payload`` already has: this module says what
the payload *is*; the view says how it is *rendered* and registers it.

What GGU-100 added, criterion by criterion (spec 0032):

* **AC-1/AC-2** — ``net``: the walk's delta as a labelled, signed money pair
  with its signed percentage and a ``direction``. The design's pill,
  *▲ Net +$3,240 (+0.68%)*, is bound from it and nothing is computed.
* **AC-3** — each step carries the figures the selected state shows: the
  step's own percentage move, the units held and the unit price, all pairs,
  plus the sentence the detail strip prints and the caption the header shows
  while that bar is selected (*BTC selected*).
* **AC-6** — ``cumulative`` stays: design binds it.
"""

from typing import Final, Literal

from pydantic import Field

from app.actions.declared import SurfaceActionRef
from app.presentation.fragments import (
    Annotation,
    Bucket,
    Delta,
    MoneyDisplay,
    PercentageDisplay,
    ProjectionDto,
    Total,
)
from app.presentation.ticket_displays import QuantityDisplay

VIEW_ID: Final[str] = "attribution.waterfall.v1"
TITLE: Final[str] = "Unrealised P/L attribution"
SUMMARY: Final[str] = (
    "Unrealised profit and loss walked from cost basis to market value, one "
    "bucket per holding, biggest move first."
)
SECTIONS: Final[tuple[str, ...]] = ("buckets", "annotations")
#: The headline's label, as the design's pill prints it.
NET_LABEL: Final[str] = "Net"


class HoldingStep(Bucket):
    """A waterfall step that is a holding, with what its selected state shows.

    ``Bucket`` stays the generic primitive — a step of any walk. A holding's
    step knows more: how far *it* moved in its own terms, how many units
    carried the move and at what price. Design's selected tooltip reads
    ``+4.2% · 90 sh · $1,204.66`` off exactly these (GGU-100 AC-3).
    """

    move: PercentageDisplay = Field(
        description="The step's own signed move, against what it cost."
    )
    units: QuantityDisplay = Field(description="Units held.")
    price: MoneyDisplay = Field(description="Today's unit price, as quoted.")
    detail: str = Field(
        max_length=64,
        description=(
            "The selected state's sentence, written here: the move, the units "
            "and the price with their separators and unit word."
        ),
        examples=["+45.73% · 90 sh · $1,204.66"],
    )
    selected_label: str = Field(
        max_length=48,
        description="What the card's header says while this step is selected.",
        examples=["BTC selected"],
    )


class AttributionWaterfallPayload(ProjectionDto):
    """The walk from what the portfolio cost to what it is worth today."""

    view: Literal["attribution.waterfall.v1"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    title: str = Field(
        max_length=120, description="Title the widget shows.", examples=[TITLE]
    )
    start: Total = Field(description="Where the walk starts: total cost basis.")
    end: Total = Field(description="Where the walk ends: total market value.")
    net: Delta = Field(
        description=(
            "The whole walk in one figure: end minus start, signed, with its "
            "share of the start and its direction — the headline pill."
        )
    )
    buckets: tuple[HoldingStep, ...] = Field(
        default=(), description="One step per holding, biggest absolute move first."
    )
    annotations: tuple[Annotation, ...] = Field(
        default=(), description="Sentences shown beside the chart, written here."
    )
    actions: tuple[SurfaceActionRef, ...] = Field(
        default=(),
        description=(
            "What tapping this surface may send back: a registered action id "
            "and the bounded argument it takes. Nothing else is accepted."
        ),
    )


__all__ = [
    "NET_LABEL",
    "SECTIONS",
    "SUMMARY",
    "TITLE",
    "VIEW_ID",
    "AttributionWaterfallPayload",
    "HoldingStep",
]
