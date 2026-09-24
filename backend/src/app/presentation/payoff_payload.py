"""What ``payoff.curve.v1`` **is** — its identity, its words and its DTO.

Split out of ``views/payoff_curve.py`` when the placeable markers arrived
(spec 0024 §4) and that module reached the 150-line budget, along the seam
``order_payload`` already cut for the ticket: *what the payload is* apart from
*how it is rendered*. The view module keeps the id, the pure ``render``, the
A2UI adapter and the ``register(...)`` call, and re-exports what this one
declares so nothing outside has to learn the new path.

The ``DISCLOSURE`` lives here rather than beside ``render`` because it is a
compliance string, not a rendering detail: it is what stops a linear spot line
being read as an options payoff, the client must print it verbatim under N-9,
and its wording is reviewed against spec 0014 OD-8 rather than against code.
"""

from typing import Final, Literal

from pydantic import Field

from app.presentation.fragments import Annotation, ProjectionDto, Series, Total
from app.presentation.payoff_markers import PayoffMarkers

VIEW_ID: Final[str] = "payoff.curve.v1"
TITLE: Final[str] = "Payoff across a price range"
SUMMARY: Final[str] = (
    "Profit and loss of a proposed buy or sell across a bounded range of "
    "future prices, entry and break-even marked. An illustrative linear spot "
    "payoff, never an options payoff."
)
DISCLOSURE: Final[str] = (
    "Illustrative linear spot payoff on the demo portfolio's simulated "
    "prices: profit or loss is (price - entry) x quantity, with no fees, no "
    "slippage and no financing. There is no strike, no expiry, no implied "
    "volatility and no time decay behind this line. A sell is the mirror of "
    "the position and leaves no position to value."
)
#: What the ``fields`` option may trim. ``markers`` is deliberately **not**
#: among them: a client that can be served a payload without them is a client
#: that needs a fallback, and the only fallback available is the label match
#: this block exists to abolish (spec 0024 §4).
SECTIONS: Final[tuple[str, ...]] = ("totals", "series", "annotations")


class PayoffCurvePayload(ProjectionDto):
    """What a proposed order makes or loses across a range of prices."""

    view: Literal["payoff.curve.v1"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    title: str = Field(
        max_length=120, description="Title the widget shows.", examples=[TITLE]
    )
    disclosure: str = Field(
        max_length=400,
        description="What this curve is and is not; shown with the chart.",
        examples=[DISCLOSURE],
    )
    markers: PayoffMarkers = Field(
        description=(
            "The break-even and the current price, each under its own field "
            "name so a widget places them by path and never by label."
        )
    )
    totals: tuple[Total, ...] = Field(
        default=(), description="Entry price, break-even price and notional."
    )
    series: tuple[Series, ...] = Field(
        default=(), description="The profit-and-loss line, ascending by price."
    )
    annotations: tuple[Annotation, ...] = Field(
        default=(), description="Sentences shown beside the chart, written here."
    )


__all__ = [
    "DISCLOSURE",
    "SECTIONS",
    "SUMMARY",
    "TITLE",
    "VIEW_ID",
    "PayoffCurvePayload",
]
