"""Where ``payoff.curve.v1`` says its two reference lines go (spec 0024 §4).

The break-even and the current price were already in the payload twice — as a
``totals[]`` row and as an ``annotations[]`` row — and neither carried a key.
``Total`` and ``Annotation`` are ``{label, amount}`` and ``{label, text}``, so
the only way to *place* the break-even rule was to match the English string
``"Break-even price"``. That is prohibition N-5 in the client (a server string
interpreted rather than printed) and it is wrong the first time ``locale``
renders the label in Spanish: the marker disappears and nothing goes red.

So the two markers get **their own field names**, which is the design's own
Zone 2 shape (``markers: { breakEven, current }``). The address of a marker is
now a path a component's author writes as a literal — ``markers.break_even`` —
rather than a comparison against data. A relabelled marker moves nothing, and
a *missing* one is a ``PayloadContractException`` naming the path instead of a
line that silently fails to be drawn.

Chosen over putting a discriminator on ``totals[]`` because ``Total`` is a
shared fragment: a required ``key`` on it would reach into every other view's
payload to solve one view's problem (ADR-K D-15), and an *optional* one would
leave the string match as the fallback it is supposed to abolish.

``current`` is the reference price at the portfolio's ``as_of``. For a
proposed order it is also the price the order is struck at, which is why
``totals[]`` calls the same figure *Entry price*: this view charts an order
that does not exist yet, so "where it would be entered" and "where the asset
is now" are one number until a fee moves them apart. The marker is named for
what the reader is looking at.
"""

from pydantic import BaseModel, ConfigDict, Field

from app.domain.payoff import PayoffCurve
from app.presentation.fragments import Labelled, MoneyDisplay
from app.presentation.payoff_figures import Shape, price

BREAK_EVEN_LABEL = "Break-even"
CURRENT_LABEL = "Current price"


class PriceMarker(Labelled):
    """One reference line on the price axis, addressed by its field name."""

    at: MoneyDisplay = Field(
        description=(
            "Where the line sits on the x axis — the exact price to place it "
            "at, and the string to print beside it."
        )
    )


class PayoffMarkers(BaseModel):
    """The two lines the chart draws across its own price axis.

    An object with two named fields rather than a list, on purpose: a list
    would put the client back to searching it, and the point of this block is
    that there is nothing to search.
    """

    model_config = ConfigDict(frozen=True)

    break_even: PriceMarker = Field(
        description="Where the order's profit crosses zero (spec 0014 OD-9)."
    )
    current: PriceMarker = Field(
        description=(
            "The reference price at the portfolio's `as_of`, which is also "
            "where this proposed order would be entered."
        )
    )


def markers(curve: PayoffCurve, shape: Shape) -> PayoffMarkers:
    """Place the break-even and the current price, at this payload's precision.

    Args:
        curve: The priced order, straight from the domain.
        shape: How this one payload writes its prices down, so a marker and
            the point it sits on never print the same price two ways.

    Returns:
        Both markers, each labelled and carrying its exact coordinate.
    """
    return PayoffMarkers(
        break_even=PriceMarker(
            label=BREAK_EVEN_LABEL, at=price(curve.break_even_price, shape)
        ),
        current=PriceMarker(label=CURRENT_LABEL, at=price(curve.entry_price, shape)),
    )


__all__ = [
    "BREAK_EVEN_LABEL",
    "CURRENT_LABEL",
    "PayoffMarkers",
    "PriceMarker",
    "markers",
]
