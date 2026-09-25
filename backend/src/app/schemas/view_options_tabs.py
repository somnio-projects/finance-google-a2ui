"""The knobs the **tabs** ask for, as query parameters (ADR-K D-2, D-3).

Split from `view_options.py` under the 150-line budget, along the seam the
module already had: that file carries what a *chart* is asked for — a symbol,
a quantity, a lot method, an order's legs — and this carries what a *screen*
is asked for: which period the hero measures, how the donut is sliced, which
rows a list keeps and what is being searched for.

`ProjectionOptions` inherits both, so the endpoint still declares one flat
set. The reason it must is recorded in `view_options.py` and is worth not
re-learning: an option a projection advertises and this model does not
declare answers **422** on `GET …/views` while `POST /v1/view-renders`
serves it, because one forwards a dict and the other is a pydantic model
with `extra="forbid"`. `test_view_query_accepts_every_registered_option`
compares the two.
"""

from typing import Annotated, Literal

from pydantic import BaseModel, Field

#: Periods the Home hero is measured over; groupings of the allocation donut.
Range = Literal["1d", "1w", "1m", "ytd", "1y", "all"]
GroupBy = Literal["holding", "asset_class", "sector"]
ActivityKind = Literal["all", "buy", "sell", "staking_reward", "deposit"]
#: `holdings.positions.v1`'s class chips. The presentation layer's
#: `AssetFilter` is the same closed set, and `tests/unit/schemas/
#: test_view_option_members.py` compares the two **member for member** —
#: the names-only comparison in `test_view_query_accepts_every_registered_
#: option` cannot see a value on one side alone, which is a 422 for
#: something the catalog advertises.
AssetClassFilter = Literal[
    "all", "layer1", "layer2", "stablecoin", "defi", "infrastructure"
]
#: A search needle. Bounded in length *and* in alphabet: it reaches no SQL,
#: no template and no log line (spec 0035 §5), and a bound that says so is
#: cheaper than a reader having to go and check.
QUERY_PATTERN = r"^[A-Za-z0-9 .&'-]{1,24}$"


class TabOptions(BaseModel):
    """What a screen — rather than a chart — may be asked for."""

    range: Range | None = Field(
        default=None,
        description="Period the Home hero's change is measured over.",
        examples=["1d"],
    )
    group_by: GroupBy | None = Field(
        default=None,
        description="How the allocation donut is sliced.",
        examples=["asset_class"],
    )
    headline: bool | None = Field(
        default=None,
        description="Whether the allocation card carries its total and gain block.",
        examples=[False],
    )
    kind: ActivityKind | None = Field(
        default=None,
        description="`activity.timeline.v1`: rows to show.",
        examples=["staking_reward"],
    )
    limit: int | None = Field(
        default=None,
        ge=1,
        le=200,
        description="`activity.timeline.v1`: newest rows kept.",
    )
    asset_class: AssetClassFilter | None = Field(
        default=None,
        description="`holdings.positions.v1`: keep only this asset class.",
        examples=["layer1"],
    )
    query: Annotated[str, Field(pattern=QUERY_PATTERN)] | None = Field(
        default=None,
        description=(
            "Narrow a list to rows whose symbol or description contains this "
            "text, case-insensitively. The projection rejects it where it is "
            "not declared."
        ),
        examples=["btc"],
    )


__all__ = [
    "QUERY_PATTERN",
    "ActivityKind",
    "AssetClassFilter",
    "GroupBy",
    "Range",
    "TabOptions",
]
