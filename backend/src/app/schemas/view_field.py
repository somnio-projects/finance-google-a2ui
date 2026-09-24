"""One row of a view's field inventory, as `GET /v1/views` serves it (spec 0034).

Split from `view_catalog.py` under the 150-line budget along the seam already
there: that module describes a *view*, this describes one *field* of its
payload. The rows are the ones `docs/catalog/view-catalog.snapshot.json` has
carried since GGU-53, now served so the developer catalog binds them rather
than a copy (`.claude/rules/frontend/testing.md` §5).
"""

from pydantic import BaseModel, ConfigDict, Field


class FieldDescriptor(BaseModel):
    """One payload path of a view and what a client may do with it."""

    model_config = ConfigDict(frozen=True)

    path: str = Field(
        max_length=128,
        description="Dotted path of the field inside the payload; `[]` marks a list.",
        examples=["buckets[].delta.display"],
    )
    type: str = Field(
        max_length=200,
        description="The declared type, with its bound where the schema states one.",
        examples=["string ≤32 chars"],
    )
    presence: str = Field(
        max_length=200,
        description="`required`, or the default the backend fills in.",
        examples=["required"],
    )
    binding: str = Field(
        max_length=32,
        description=(
            "How a client binds it: `display` (a pre-formatted figure), `raw` "
            "(a decimal for chart geometry only), `text`, `enum`, `constant` "
            "or `container`."
        ),
        examples=["display"],
    )
    state: str | None = Field(
        default=None,
        max_length=32,
        description=(
            "The component state this field drives (`empty`, `variant`, "
            "`null`), or null when it drives none."
        ),
        examples=["empty"],
    )
    input: str | None = Field(
        default=None,
        max_length=400,
        description=(
            "The declared option that sets this field and its bound, or null "
            "for a read-only field. Naming an option is the interactivity "
            "declaration (ADR-K D-3)."
        ),
        examples=["input · one of 'holding', 'asset_class', 'sector'"],
    )


__all__ = ["FieldDescriptor"]
