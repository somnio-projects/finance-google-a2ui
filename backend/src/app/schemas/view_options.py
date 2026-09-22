"""The per-projection options `GET …/views` accepts (ADR-K D-2, D-3).

Split from `views.py` under the 150-line budget, along the seam that was
already there: that module declares the endpoint's **envelope**, this declares
the knobs a projection can be asked for.

**Why this module exists at all.** GGU-41 added four projections with nine
options between them and nothing extended this query model, which carries
`extra="forbid"`: the catalog advertised `symbol`, `quantity`, `lot_method`,
`methods`, `side`, `size`, `size_in`, `range_pct` and `steps` while
`GET /v1/portfolios/{id}/views?view=…&symbol=NVDA` answered **422** for every
one, and `POST /v1/view-renders` — which forwards a dict — served the same
request with a 201. Two declarations of one fact, compared by nothing until
`test_view_query_accepts_every_registered_option`.

**What these bounds are, and are not.** They are "could any registered view
accept this?", not "is this valid for the view you asked for". Several options
share a name with a different schema per view — `quantity`, `side`, `size`,
`size_in`, `symbol` — so a flat model carries the union; the projection's own
strict options model runs right after, and an out-of-range value is its 422.

`symbol` is a pattern, not the market reference's tickers: enumerating them
here would put the asset list in two places, and the projection rejects one
it does not hold. `legs` copies the domain's pattern for the same reason, and
`test_order_ticket_v2_options` compares the two copies.
"""

from typing import Annotated, Literal

from pydantic import Field

from app.schemas.view_options_tabs import TabOptions

#: Lot-selection strategies (`domain/lot_selection.py`).
LotMethod = Literal["FIFO", "LIFO", "HIFO"]
#: Which way an order goes, and what its `size` counts.
Side = Literal["buy", "sell"]
SizeIn = Literal["units", "usd"]
#: A decimal string, never a float (ADR-E D-5).
DECIMAL_PATTERN = r"^[0-9]{1,9}(\.[0-9]{1,8})?$"
#: A ticker of the market reference; membership is the projection's to enforce.
TICKER_PATTERN = r"^[A-Z]{2,10}$"
#: `order.ticket.v2`'s legs, `TICKER:SHARES` pairs (`domain/draft_legs.py`).
LEGS_PATTERN = r"^[A-Z]{2,10}:[0-9]{1,6}(,[A-Z]{2,10}:[0-9]{1,6}){0,4}$"


class ProjectionOptions(TabOptions):
    """Options a projection may be asked for, as query parameters.

    The chart knobs are declared here; the screen knobs come from
    `TabOptions` (`view_options_tabs.py`), which is where the 150-line
    budget put the seam.
    """

    symbol: Annotated[str, Field(pattern=TICKER_PATTERN)] | None = Field(
        default=None,
        description=(
            "Asset the view is about; the projection rejects one it does not hold."
        ),
        examples=["NVDA"],
    )
    quantity: Annotated[str, Field(pattern=DECIMAL_PATTERN)] | None = Field(
        default=None,
        description="Units the scenario disposes of, as a decimal string.",
        examples=["0.5"],
    )
    lot_method: LotMethod | None = Field(
        default=None,
        description=(
            "Which lots a sale consumes first: FIFO oldest, LIFO newest, HIFO dearest."
        ),
        examples=["FIFO"],
    )
    methods: list[LotMethod] | None = Field(
        default=None,
        max_length=3,
        description=(
            "Lot-selection methods to compare, in the order shown; repeat the "
            "parameter."
        ),
        examples=[["FIFO", "HIFO"]],
    )
    side: Side | None = Field(
        default=None,
        description="Which way the order goes; `sell` disposes of units held.",
        examples=["buy"],
    )
    size: Annotated[str, Field(pattern=DECIMAL_PATTERN)] | None = Field(
        default=None,
        description="How big the order is, as a decimal string (ADR-E D-5).",
        examples=["0.25"],
    )
    size_in: SizeIn | None = Field(
        default=None,
        description="What `size` counts: units of the asset, or US dollars.",
        examples=["usd"],
    )
    range_pct: int | None = Field(
        default=None,
        ge=5,
        le=90,
        description="How far above and below the entry price to plot, in percent.",
        examples=[30],
    )
    steps: int | None = Field(
        default=None,
        ge=1,
        le=25,
        description="Price steps per side; the line is twice this plus one point.",
        examples=[12],
    )
    legs: Annotated[str, Field(pattern=LEGS_PATTERN)] | None = Field(
        default=None, description="`order.ticket.v2`: `TICKER:SHARES` pairs."
    )


__all__ = [
    "DECIMAL_PATTERN",
    "TICKER_PATTERN",
    "LotMethod",
    "ProjectionOptions",
    "Side",
    "SizeIn",
]
