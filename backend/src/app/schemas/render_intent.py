"""What the model asks for, and what it gets back (ADR-K D-11/D-12).

These DTOs have **no HTTP surface**: the agent turn (GGU-47) is the caller.
They live in ``schemas`` anyway because they are the contract between the tool
layer and the presentation layer, and because the day the render intent is
echoed in a trace it must already be a documented, bounded shape.
"""

from typing import Any

from pydantic import BaseModel, ConfigDict, Field, SerializeAsAny

from app.presentation.fragments import ProjectionDto
from app.presentation.surfaces import Surface
from app.schemas.views import ViewId


class RenderIntent(BaseModel):
    """The model's choice: a registered view id and its declared options."""

    model_config = ConfigDict(frozen=True, extra="forbid")

    view: ViewId = Field(
        description="Registered projection the model picked; never invented.",
        examples=["attribution.waterfall.v1"],
    )
    options: dict[str, Any] = Field(
        default_factory=dict,
        description="Declared options to fill; anything else is rejected.",
        examples=[{"precision": 2, "locale": "es-AR"}],
    )


class RenderedIntent(BaseModel):
    """The rendered answer, plus why a fallback happened when one did."""

    model_config = ConfigDict(frozen=True)

    view: str = Field(
        max_length=64,
        description="The projection actually rendered — the default on fallback.",
        examples=["attribution.waterfall.v1"],
    )
    payload: SerializeAsAny[ProjectionDto] = Field(
        description="The rendered payload, discriminated by its `view` field."
    )
    surface: Surface = Field(description="The A2UI surface the client renders.")
    rejection: str | None = Field(
        default=None,
        description="Why the model's choice was refused; `null` when accepted.",
        examples=["view 'nope.v1' is not registered"],
    )


__all__ = ["RenderIntent", "RenderedIntent"]
