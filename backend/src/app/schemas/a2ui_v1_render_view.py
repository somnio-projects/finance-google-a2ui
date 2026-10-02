"""The arguments of ``renderView`` (ADR-M D-6, spec 0053 §5).

The catalog publishes this shape as JSON Schema for the renderer; this is the
same shape held at the boundary, because a catalog is a promise the renderer
reads and not a check the agent can rely on.

Three bounds, each for a reason:

* ``componentId`` is the data-model key the answer writes to, so it is an
  identifier — never a JSON Pointer the caller could aim elsewhere;
* ``view`` is a registered id in shape; whether it exists is the registry's;
* ``options`` keys are option names in shape and at most sixteen. Their
  values are judged by the projection's own options model (ADR-K D-3).
"""

from typing import Annotated, Any, Final

from pydantic import BaseModel, ConfigDict, Field, StringConstraints

from app.presentation.a2ui_v1.wire import COMPONENT_ID_PATTERN
from app.schemas.views import ViewId

#: How many options one call may name; no projection declares more.
MAX_OPTIONS: Final[int] = 16

OptionName = Annotated[str, StringConstraints(pattern=r"^[a-z][a-z0-9_]{0,31}$")]


class RenderViewArgs(BaseModel):
    """What a renderer passes to ``renderView``; nothing else is accepted."""

    model_config = ConfigDict(frozen=True, extra="forbid", populate_by_name=True)

    component_id: str = Field(
        alias="componentId",
        pattern=COMPONENT_ID_PATTERN,
        description="The component to re-render, which is also its data path.",
        examples=["root"],
    )
    view: ViewId = Field(
        description="The registered projection to render.",
        examples=["portfolio.summary.v1"],
    )
    options: dict[OptionName, Any] = Field(
        max_length=MAX_OPTIONS,
        description="The view's declared options; judged by its own model.",
        examples=[{"range": "1y"}],
    )


__all__ = ["MAX_OPTIONS", "OptionName", "RenderViewArgs"]
