"""Reusable DTO primitives every projection is built from (ADR-K D-16).

The tenth chart must reuse what the first nine established instead of
inventing a tenth vocabulary, so a new projection composes these fragments and
only adds a primitive here — with its tests — when it genuinely needs one.

The figure/string pairs live in ``app.presentation.displays``, the shared base
in ``app.presentation.labels`` and the plotting primitives in
``app.presentation.plot_fragments``; all of them are re-exported here, so a
projection imports the whole vocabulary from one place even though the 150-line
budget split it across four files.
"""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.core.trend import Trend
from app.presentation.displays import (
    MoneyDisplay,
    PercentageDisplay,
    money,
    percentage,
)
from app.presentation.labels import Labelled
from app.presentation.plot_fragments import Annotation, Series, SeriesPoint


class ProjectionDto(BaseModel):
    """Base of every projection payload; subclasses add the ``view`` literal."""

    model_config = ConfigDict(frozen=True)


class Total(Labelled):
    """A headline figure the widget shows on its own."""

    amount: MoneyDisplay = Field(description="The figure, exact and formatted.")


class SignedTotal(Total):
    """A headline figure whose **sign** is part of what it says (GGU-117).

    The tax-lot footer's realised result: the design colours it, and the client
    may neither read the sign off the string (N-1) nor compare the number
    (N-2), so the payload has to say which way it points.

    A separate fragment rather than an optional field on ``Total``, because
    almost every headline figure in every projection has no direction and would
    carry a field nothing binds — which is what spec 0024 §7 deleted fields for
    (spec 0049 OD-4). ``direction`` is spelled as ``Delta`` spells it; the
    ``trend`` on ``TaxLotRow`` one level down is the older spelling of the same
    concept and is left alone rather than renamed under a bound client.
    """

    direction: Trend = Field(
        description="Sign of the figure, decided from the rounded value so a "
        "half-cent loss is `flat` beside a `$0.00`.",
        examples=["up"],
    )


class Delta(Labelled):
    """A signed move under a label: how much, what share, which way (GGU-100).

    The waterfall's headline pill, *Net +$3,240 (+0.68%)*. Both figures carry
    their sign, so the client never prepends one (N-1); ``direction`` picks
    the glyph and the colour.
    """

    amount: MoneyDisplay = Field(description="The move, signed and formatted.")
    percent: PercentageDisplay = Field(description="The move as a signed ratio.")
    direction: Trend = Field(
        description="Sign of the move, so the widget colours it without maths."
    )


class Category(Labelled):
    """One slice of a breakdown: a share of a whole."""

    key: str = Field(
        max_length=32,
        description="Stable identifier of the slice (a ticker, or `other`).",
        examples=["BTC"],
    )
    value: MoneyDisplay = Field(description="What the slice is worth.")
    weight: PercentageDisplay = Field(description="The slice's share of the whole.")


class Bucket(Labelled):
    """One step of a waterfall: a signed move and the running total after it."""

    key: str = Field(
        max_length=32,
        description=(
            "Stable identifier of the step, and the value a tap sends back. "
            "A surface action's argument accepts exactly these (GGU-53): the "
            "`label` is prose and cannot be sent, so a segment without a key "
            "is a segment that cannot start a turn."
        ),
        examples=["BTC"],
    )
    delta: MoneyDisplay = Field(description="How much this step moved the total.")
    cumulative: MoneyDisplay = Field(description="The running total after the step.")
    direction: Literal["up", "down"] = Field(
        description="Sign of the step, so the widget colours it without maths.",
        examples=["up"],
    )


__all__ = [
    "Annotation",
    "Bucket",
    "Category",
    "Delta",
    "Labelled",
    "MoneyDisplay",
    "PercentageDisplay",
    "ProjectionDto",
    "Series",
    "SeriesPoint",
    "SignedTotal",
    "Total",
    "money",
    "percentage",
]
