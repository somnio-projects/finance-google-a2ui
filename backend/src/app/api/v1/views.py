"""View-catalog controller — what the client may ask the backend to render."""

from typing import Annotated

from fastapi import APIRouter, Depends

from app.api.deps import get_current_principal, get_view_service
from app.api.feature_gate import require_feature
from app.api.openapi import AUTHENTICATED, problem_responses
from app.schemas.views import ViewDescriptor
from app.services.view_service import ViewService

router = APIRouter(prefix="/v1/views", tags=["views"])
ViewsDep = Annotated[ViewService, Depends(get_view_service)]


@router.get(
    "",
    response_model=list[ViewDescriptor],
    operation_id="list_view_catalog",
    summary="List every projection the backend can render",
    description=(
        "Returns the catalog of registered projections — id, one-line purpose, "
        "the endpoints that serve it, the JSON schema of the options it "
        "declares and an example payload it really renders. This is how a "
        "client discovers what it can ask for without guessing (ADR-K D-8). "
        "The catalog describes shapes, never portfolio data, but a bearer "
        "token is still required. Spec 0005 AC-8."
    ),
    responses=problem_responses(*AUTHENTICATED, 404, 503),
    dependencies=[
        require_feature("views.catalog"),
        Depends(get_current_principal),
    ],
)
async def list_view_catalog(service: ViewsDep) -> list[ViewDescriptor]:
    """Describe every registered projection. Spec 0005 AC-8."""
    return await service.catalog()


__all__ = ["router"]
