"""View-catalog controller — what the client may ask the backend to render."""

from typing import Annotated, Any, Final

from fastapi import APIRouter, Depends, Response

from app.api.caching import NOT_MODIFIED_RESPONSE, ConditionalDep, strong_etag
from app.api.deps import get_current_principal, get_view_service
from app.api.feature_gate import require_feature
from app.api.openapi import AUTHENTICATED, problem_responses
from app.presentation.contract import catalog_entry
from app.presentation.registry import REGISTRY
from app.presentation.views import LOADED
from app.schemas.views import ViewDescriptor
from app.services.view_service import ViewService

router = APIRouter(prefix="/v1/views", tags=["views"])
ViewsDep = Annotated[ViewService, Depends(get_view_service)]

#: Importing the views package is what fills the registry the example reads.
VIEWS: Final[tuple[str, ...]] = LOADED
#: Rendered from the registry, never hand-written: the documented catalog is
#: the served catalog, entry for entry (spec 0005 OD-2).
CATALOG: Final[list[dict[str, Any]]] = [
    catalog_entry(projection) for projection in REGISTRY.all()
]
#: The registry cannot change after import, so the catalog's entity tag is a
#: process constant. Deriving it per request would re-dump every options
#: schema on the 304 path too — the compute revalidation exists to avoid.
CATALOG_ETAG: Final[str] = strong_etag("views-catalog", CATALOG)
SUCCESS: Final[dict[int | str, dict[str, Any]]] = {
    200: {
        "description": "Every registered projection, ordered by id.",
        "content": {"application/json": {"example": CATALOG}},
    }
}


@router.get(
    "",
    response_model=list[ViewDescriptor],
    operation_id="list_view_catalog",
    summary="List every projection the backend can render",
    description=(
        "Returns the catalog of registered projections — id, one-line purpose, "
        "the endpoints that serve it, the JSON schema of the options it "
        "declares, the A2UI `component` a rendered surface instantiates, the "
        "`actions` that surface may send back, the `guidance` that says when "
        "to pick this view (null where design has not written one) and an "
        "example payload it really renders. This is how a "
        "client discovers what it can ask for without guessing (ADR-K D-8). "
        "The catalog describes shapes, never portfolio data, but a bearer "
        "token is still required. Spec 0005 AC-8, 0022 AC-11, 0023 AC-4."
    ),
    responses={
        **SUCCESS,
        **NOT_MODIFIED_RESPONSE,
        **problem_responses(*AUTHENTICATED, 404, 503),
    },
    dependencies=[
        require_feature("views.catalog"),
        Depends(get_current_principal),
    ],
)
async def list_view_catalog(
    service: ViewsDep, conditional: ConditionalDep
) -> list[ViewDescriptor] | Response:
    """Describe every registered projection. Spec 0005 AC-8.

    The registry is fixed at import, so the catalog's entity tag is computed
    once for the process and a client revalidates it for the price of one
    header (ADR-K D-20, spec 0012 AC-8).
    """
    return conditional.resolve(await service.catalog(), etag=CATALOG_ETAG)


__all__ = ["CATALOG_ETAG", "VIEWS", "router"]
