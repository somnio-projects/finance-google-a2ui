"""The `GET /v1/views` catalog entry (ADR-K D-8).

Split from `views.py` under the 150-line budget along the seam already there:
that module is the **render** endpoint's envelope, this is the **catalog**
entry — a different endpoint answering a different question.

What it publishes comes from the projection's own registration, never from a
hand-kept list, which is what makes the catalog unable to drift from the
registry. It can still drift from the *render endpoint*, and did:
`test_view_query_options.py` is what compares those two now.
"""

from typing import Any

from pydantic import BaseModel, ConfigDict, Field


class ViewDescriptor(BaseModel):
    """One entry of the `/v1/views` catalog (ADR-K D-8)."""

    model_config = ConfigDict(frozen=True)

    id: str = Field(
        max_length=64,
        description="Versioned projection id to pass as `?view=`.",
        examples=["holdings.allocation.v1"],
    )
    summary: str = Field(
        max_length=300,
        description="What the projection shows, in one line.",
        examples=["Allocation by holding: market value and weight per symbol."],
    )
    endpoints: list[str] = Field(
        description="The endpoints that serve this projection.",
        examples=[["GET /v1/portfolios/{portfolio_id}/views", "POST /v1/view-renders"]],
    )
    options_schema: dict[str, Any] = Field(
        description="JSON schema of the options this projection declares.",
        examples=[{"properties": {"precision": {"type": "integer"}}}],
    )
    actions: list[dict[str, Any]] = Field(
        default_factory=list,
        description=(
            "Actions a surface rendered from this projection may send back "
            "(spec 0022 §3.4): a registered id, the single argument it takes "
            "and that argument's bound. Empty when the projection offers none."
        ),
        examples=[
            [
                {
                    "action": "drill.attribution.v1",
                    "label": "Break this down",
                    "arg": "driver",
                    "control": "choice",
                    "choices": ["ADA", "BTC", "DOGE", "ETH"],
                }
            ]
        ],
    )
    example: dict[str, Any] = Field(
        description="A payload this projection really renders, for the client.",
        examples=[{"view": "holdings.allocation.v1"}],
    )


__all__ = ["ViewDescriptor"]
