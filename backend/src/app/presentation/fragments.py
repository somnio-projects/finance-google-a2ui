"""Reusable DTO primitives every projection is built from (ADR-K D-16).

The tenth chart must reuse what the first nine established instead of
inventing a tenth vocabulary, so a new projection composes these fragments and
only adds a primitive here — with its tests — when it genuinely needs one.

The figure/string pairs live in ``app.presentation.displays`` and are
re-exported here, so a projection imports the whole vocabulary from one place.
"""

from typing import Literal

from pydantic import BaseModel, ConfigDict, Field

from app.domain.day_change import Trend
from app.presentation.displays import (
    MoneyDisplay,
    PercentageDisplay,
    money,
    percentage,
)


class ProjectionDto(BaseModel):
    """Base of every projection payload; subclasses add the ``view`` literal."""

    model_config = ConfigDict(frozen=True)


class Labelled(BaseModel):
    """A fragment the widget shows under a human label."""

    model_config = ConfigDict(frozen=True)

    label: str = Field(
        max_length=64,
        description="Human label the widget shows.",
        examples=["NVIDIA Corp"],
    )


class Total(Labelled):
    """A headline figure the widget shows on its own."""

    amount: MoneyDisplay = Field(description="The figure, exact and formatted.")


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


class SeriesPoint(Labelled):
    """One observation of a series: where it sits, and what it is worth there.

    ``at`` is the **x** coordinate as an ADR-E pair, and it is what makes the
    series drawable. ``label`` is the axis tick a widget prints; a client
    given only that would have to parse ``"$142.50"`` back into a number to
    place the point, which is the client-side arithmetic ADR-K D-5 exists to
    remove (GGU-53).
    """

    at: MoneyDisplay = Field(
        description="Where the point sits on the x axis — exact, and formatted."
    )
    value: MoneyDisplay = Field(description="The observed figure at this point.")


class Series(BaseModel):
    """A named sequence of observations the widget plots as one line."""

    model_config = ConfigDict(frozen=True)

    name: str = Field(
        max_length=64, description="Name of the series.", examples=["BTC"]
    )
    points: tuple[SeriesPoint, ...] = Field(
        description="The observations, oldest first."
    )


class Annotation(Labelled):
    """A sentence the widget shows beside the chart, written server-side."""

    text: str = Field(
        max_length=200,
        description="The sentence to show; it already contains its numbers.",
        examples=["contributed $8,925.00"],
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
    "Total",
    "money",
    "percentage",
]
