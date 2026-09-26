"""The comparison's declared tax knobs, as query parameters (spec 0051).

A mixin rather than three more fields on ``ProjectionOptions``, which is at
the file budget — the same shape ``TabOptions`` already takes.

The bound is imported from ``domain.scenario_tax`` rather than restated. This
model and the projection's own options both publish it, and two spellings of
one bound is where a query parameter starts accepting what the projection
refuses.
"""

from typing import Annotated

from pydantic import BaseModel, Field

from app.domain.scenario_tax import RATE_PATTERN


class TaxOptions(BaseModel):
    """What a caller may say about tax on a scenario comparison."""

    short_term_rate: Annotated[str, Field(pattern=RATE_PATTERN)] | None = Field(
        default=None,
        description=(
            "Rate applied to the short-term part of a gain, as a decimal "
            "string. A declared assumption the comparison prints beside the "
            "figure it produces."
        ),
        examples=["0.35"],
    )
    long_term_rate: Annotated[str, Field(pattern=RATE_PATTERN)] | None = Field(
        default=None,
        description="Rate applied to the long-term part of a gain.",
        examples=["0.15"],
    )
    include_wait: bool | None = Field(
        default=None,
        description=(
            "Add the comparison's *Wait for long-term* column: the same sale "
            "past every lot's first anniversary, at today's price."
        ),
        examples=[True],
    )


__all__ = ["TaxOptions"]
