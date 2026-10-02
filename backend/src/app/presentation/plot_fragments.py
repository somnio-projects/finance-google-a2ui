"""The plotting half of the shared vocabulary (ADR-K D-16).

Split out of ``fragments`` when that file went over the 150-line budget, along
the seam the vocabulary already had: everything here describes **where a figure
sits** — a sequence of observations and the sentence a widget prints beside it
— while ``fragments`` describes **a figure under a label**.

Nothing imports this module directly. ``fragments`` re-exports all three names,
so a projection still imports the whole vocabulary from one place, which is the
property that split had to preserve.
"""

from pydantic import BaseModel, ConfigDict, Field

from app.presentation.displays import MoneyDisplay
from app.presentation.labels import Labelled


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


__all__ = ["Annotation", "Series", "SeriesPoint"]
