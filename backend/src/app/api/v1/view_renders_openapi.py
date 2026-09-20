"""What `POST /v1/view-renders` looks like in the document (ADR-K D-4, D-18).

The response model and both examples live here rather than in the controller
for the same reason the controller has no logic: they are a different
responsibility — and, together, more lines than the route itself.

Everything is built **from the registry**, so a projection added under
`presentation/views/` joins this operation's `oneOf` and its example with no
file here being edited (ADR-K D-15).
"""

from typing import Any, Final

from fastapi.openapi.models import Example
from pydantic import BaseModel, Field, create_model

from app.core.errors import PROBLEM_TYPE_BASE
from app.presentation.contract import payload_annotation
from app.presentation.registry import REGISTRY
from app.presentation.sample import EXAMPLE_AS_OF
from app.presentation.views import LOADED
from app.schemas.view_renders import ViewRenderResult
from app.schemas.views import CURRENT_PORTFOLIO

#: Importing the views package is what fills the registry; ``LOADED`` is the
#: proof it happened before the union below was built.
VIEWS: Final[tuple[str, ...]] = LOADED
AS_OF: Final[str] = EXAMPLE_AS_OF.isoformat().replace("+00:00", "Z")
UNKNOWN_VIEW: Final[str] = "nope.thing.v1"


def _batch_model() -> type[BaseModel]:
    """Build the response model whose entries carry the projection union."""
    entry = create_model(
        "ViewRenderEntryResult",
        __base__=ViewRenderResult,
        __doc__=(
            "One entry's outcome: the status it alone answers with, and "
            "either the projection it rendered or the problem it produced."
        ),
        payload=(
            payload_annotation(REGISTRY.all()) | None,
            Field(
                default=None,
                description="The rendered projection, discriminated by `view`.",
            ),
        ),
    )
    return create_model(
        "ViewRenderBatchResults",
        __doc__=(
            "Every entry's outcome, in request order. An entry carries either "
            "a rendered payload or the problem document it alone produced."
        ),
        results=(
            list[entry],
            Field(description="One result per requested entry, in request order."),
        ),
    )


DOCUMENTED: Final[type[BaseModel]] = _batch_model()

#: A batch a real client would send: two renderable entries and one that is
#: not, so the per-entry status is visible in the documentation itself.
REQUEST_EXAMPLE: Final[dict[str, Any]] = {
    "renders": [
        {"view": "holdings.allocation.v1", "portfolio_id": CURRENT_PORTFOLIO},
        {
            "view": "attribution.waterfall.v1",
            "portfolio_id": CURRENT_PORTFOLIO,
            "options": {"precision": 2},
        },
        {"view": UNKNOWN_VIEW, "portfolio_id": CURRENT_PORTFOLIO},
    ]
}

REQUEST_EXAMPLES: Final[dict[str, Example]] = {
    "mixed": Example(
        summary="Two renderable entries and one unknown view",
        value=REQUEST_EXAMPLE,
    )
}


def _rendered_entry() -> dict[str, Any]:
    """Return one successful entry, rendered from the registry itself."""
    projection = REGISTRY.all()[-1]
    return {
        "status": 200,
        "view": projection.id,
        "portfolio_id": CURRENT_PORTFOLIO,
        "as_of": AS_OF,
        "payload": dict(projection.example),
    }


CREATED: Final[dict[int | str, dict[str, Any]]] = {
    201: {
        "description": "The batch was rendered; read each entry's own `status`.",
        "content": {
            "application/json": {
                "example": {
                    "results": [
                        _rendered_entry(),
                        {
                            "status": 404,
                            "view": UNKNOWN_VIEW,
                            "portfolio_id": CURRENT_PORTFOLIO,
                            "error": {
                                "type": (f"{PROBLEM_TYPE_BASE}portfolio/unknown-view"),
                                "title": "Not Found",
                                "status": 404,
                                "detail": f"view {UNKNOWN_VIEW!r} is not registered",
                            },
                        },
                    ]
                }
            }
        },
    }
}

__all__ = ["CREATED", "DOCUMENTED", "REQUEST_EXAMPLES", "VIEWS"]
