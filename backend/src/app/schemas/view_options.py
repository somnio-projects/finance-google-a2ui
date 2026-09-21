"""The per-projection options `GET …/views` accepts (ADR-K D-2, D-3).

Split from `views.py` under the 150-line budget, along the seam that was
already there: that module declares the endpoint's **envelope**, this declares
the knobs a projection can be asked for.

**Why this module exists at all.** GGU-41 added four projections, each with
options of its own, and nothing extended the endpoint's query model — which
carries `extra="forbid"`. So `GET /v1/views` advertised `symbol`, `quantity`,
`lot_method`, `methods`, `side`, `size`, `size_in`, `range_pct` and `steps`,
and `GET /v1/portfolios/{id}/views?view=…&symbol=BTC` answered **422** for
every one of them. Four of six projections were unreachable by the client
path while the catalog promised them, and `POST /v1/view-renders` — which
forwards options as a dict and lets the projection validate — served the
identical request with a 201. The catalog and the endpoint were two
declarations of one fact, and nothing compared them.

`test_view_query_accepts_every_registered_option` is what compares them now.

**What these bounds are, and are not.** They are "could any registered view
accept this?", not "is this valid for the view you asked for". Several options
share a name with a different schema per view — `quantity`, `side`, `size`,
`size_in`, `symbol` — so a flat model can only carry the union. The
projection's own options model runs immediately afterwards and is strict; an
out-of-range value is still a 422, raised by the owner of the rule.

`symbol` is a pattern rather than the eight tickers of the market reference on
purpose: enumerating them here would put the asset list in two places, and the
projection already rejects a symbol it does not hold.
"""

from typing import Annotated, Literal

from pydantic import BaseModel, Field

#: Lot-selection strategies (`domain/lot_selection.py`).
LotMethod = Literal["FIFO", "LIFO", "HIFO"]
#: Which way an order goes.
Side = Literal["buy", "sell"]
#: What an order's `size` counts.
SizeIn = Literal["units", "usd"]
#: A decimal string, never a float (ADR-E D-5).
DECIMAL_PATTERN = r"^[0-9]{1,9}(\.[0-9]{1,8})?$"
#: A ticker of the market reference; membership is the projection's to enforce.
TICKER_PATTERN = r"^[A-Z]{2,10}$"


class ProjectionOptions(BaseModel):
    """Options a projection may be asked for, as query parameters."""

    symbol: Annotated[str, Field(pattern=TICKER_PATTERN)] | None = Field(
        default=None,
        description=(
            "Asset the view is about; the projection rejects one it does not hold."
        ),
        examples=["BTC"],
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


__all__ = [
    "DECIMAL_PATTERN",
    "TICKER_PATTERN",
    "LotMethod",
    "ProjectionOptions",
    "Side",
    "SizeIn",
]
