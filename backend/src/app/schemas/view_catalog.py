"""The `GET /v1/views` catalog entry (ADR-K D-8).

Split from `views.py` under the 150-line budget along the seam already there:
that module is the **render** endpoint's envelope, this is the **catalog**
entry — a different endpoint answering a different question.

What it publishes comes from the projection's own registration, never from a
hand-kept list, which is what makes the catalog unable to drift from the
registry. It can still drift from the *render endpoint*, and did:
`test_view_query_options.py` is what compares those two now.
"""

from typing import Any, Final

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.view_field import FieldDescriptor

#: Bound on each guidance sentence. Mirrors `presentation.guidance.MAX_SENTENCE`
#: — `schemas/` may not import `presentation`, so the two are compared by a
#: test rather than shared through an import that would break the layering.
GUIDANCE_SENTENCE_MAX: Final[int] = 400


class GuidanceDescriptor(BaseModel):
    """The do/don't pair the catalog publishes for one view (spec 0023 §4).

    A **second declaration** of `presentation.guidance.Guidance`, on purpose:
    `schemas/` may not import `presentation` (`architecture.md`), and a
    `dict[str, Any]` here would generate `Map<String, dynamic>` in a client
    for a shape that is closed and already modelled. Two declarations of one
    fact get a test comparing them, which is
    `test_guidance.py::test_the_published_descriptor_matches_the_declared_pair`
    — the same rule this whole ticket is about.
    """

    model_config = ConfigDict(frozen=True)

    use_when: str = Field(
        max_length=GUIDANCE_SENTENCE_MAX,
        description="The question this view answers, in the model's words.",
        examples=["the user asks why a value changed"],
    )
    avoid_when: str = Field(
        max_length=GUIDANCE_SENTENCE_MAX,
        description="The question it does not answer, naming the view that does.",
        examples=["a breakdown of what is held now — `holdings.allocation.v1`"],
    )


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
    component: str = Field(
        max_length=64,
        description=(
            "The A2UI component a surface rendered from this projection "
            "instantiates — the string the client registers its widget under. "
            "Read from the projection's own adapter, so this catalog and the "
            "rendered surface can never name it differently (GGU-53)."
        ),
        examples=["HoldingsSummary"],
    )
    guidance: GuidanceDescriptor | None = Field(
        default=None,
        description=(
            "When to pick this view and when to pick another, as the design "
            "catalog words it. Null for a projection whose design page has "
            "not been written — the catalog states what design decided, never "
            "a sentence invented here."
        ),
    )
    endpoints: list[str] = Field(
        description="The endpoints that serve this projection.",
        examples=[["GET /v1/portfolios/{portfolio_id}/views", "POST /v1/view-renders"]],
    )
    options_schema: dict[str, Any] = Field(
        description="JSON schema of the options this projection declares.",
        examples=[{"properties": {"precision": {"type": "integer"}}}],
    )
    fields: list[FieldDescriptor] = Field(
        description=(
            "Every path of the rendered payload with its type, presence, "
            "binding, the state it drives and the option that sets it — the "
            "field inventory the frozen contract prints (spec 0034)."
        ),
    )
    prompt: str = Field(
        max_length=2000,
        description=(
            "The lines the system prompt carries for this view, verbatim: its "
            "purpose, its options with their bounds and, where design wrote "
            "one, the do/don't pair. What the agent is taught, not a summary "
            "of it (spec 0034)."
        ),
        examples=["- holdings.allocation.v1 — Allocation by holding.\n  options: …"],
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
                    "choices": ["JNJ", "NVDA", "XOM", "AAPL"],
                }
            ]
        ],
    )
    example: dict[str, Any] = Field(
        description="A payload this projection really renders, for the client.",
        examples=[{"view": "holdings.allocation.v1"}],
    )


__all__ = [
    "GUIDANCE_SENTENCE_MAX",
    "FieldDescriptor",
    "GuidanceDescriptor",
    "ViewDescriptor",
]
