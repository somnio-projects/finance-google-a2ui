"""The payload of ``scenario.comparison.v1``, and the sentences on it (spec 0051).

Split from the view at the file budget when the redesign added the row-major
table, the footer and the declared tax rates. The seam is the usual one: what
the card **is**, apart from how the projection is wired.
"""

from decimal import Decimal
from typing import Final, Literal

from pydantic import Field

from app.presentation.fragments import Annotation, ProjectionDto
from app.presentation.scenario_columns import ScenarioColumn
from app.presentation.scenario_options import ScenarioComparisonOptions
from app.presentation.scenario_rows import ScenarioRow, ScenarioSummary
from app.presentation.scenarios import (
    NOTES,
    SAME,
    WAITS,
    ScenarioSpread,
    ScenarioSubject,
)

VIEW_ID: Final[str] = "scenario.comparison.v1"
TITLE: Final[str] = "Same sale, different lot method"
SUMMARY: Final[str] = (
    "The same proposed sale costed under each lot-selection method, so the "
    "realised result and the short/long split can be compared side by side. "
    "It marks which column keeps the most after tax, at rates the caller "
    "declares and the card prints."
)


class ScenarioComparisonPayload(ProjectionDto):
    """One proposed sale, costed under each method the caller asked for."""

    view: Literal["scenario.comparison.v1"] = Field(
        default=VIEW_ID, description="Projection discriminator.", examples=[VIEW_ID]
    )
    title: str = Field(
        max_length=120, description="Title the widget shows.", examples=[TITLE]
    )
    subject: ScenarioSubject = Field(description="What every column holds fixed.")
    columns: tuple[ScenarioColumn, ...] = Field(
        description="One column per method, in the requested order — never sorted."
    )
    rows: tuple[ScenarioRow, ...] = Field(
        description=(
            "The comparison row-major, as the frame draws it: one entry per "
            "metric, each naming the column that wins it. The figures stay "
            "in `columns[]` under the same names."
        )
    )
    summary: ScenarioSummary = Field(
        description="The header pill and the footer sentence, composed here."
    )
    spread: ScenarioSpread = Field(description="The gap between the extremes.")
    notes: tuple[Annotation, ...] = Field(
        default=(), description="Sentences shown beside the card, written here."
    )


def notes_for(
    options: ScenarioComparisonOptions, *, differs: bool
) -> tuple[Annotation, ...]:
    """The card's sentences, with the declared rates written into them.

    The rates are a **visible** assumption or they are an invented tax claim
    (GGU-134), so the note that states them is composed from the options this
    render actually used rather than from a constant that could drift from
    them.
    """
    rates = tuple(
        note.model_copy(
            update={
                "text": note.text.format(
                    short=options.percentage(Decimal(options.short_term_rate)).display,
                    long=options.percentage(Decimal(options.long_term_rate)).display,
                )
            }
        )
        if "{short}" in note.text
        else note
        for note in NOTES
    )
    waiting = (WAITS,) if options.include_wait else ()
    return (*rates, *waiting) if differs else (*rates, *waiting, SAME)


__all__ = [
    "SUMMARY",
    "TITLE",
    "VIEW_ID",
    "ScenarioComparisonPayload",
    "notes_for",
]
