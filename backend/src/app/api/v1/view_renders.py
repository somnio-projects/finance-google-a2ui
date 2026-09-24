"""Batch render controller — several projections, one round trip (ADR-K D-18).

The batch **is** the resource: `POST` creates one, the server renders it and
answers it inline. Nothing durable is created, so the 201 carries no
`Location`: the batch is not retrievable afterwards, and inventing an address
for a computed body would be a lie in the contract (spec 0012 OD-1).

The response model and the examples are built from the registry next door, in
`view_renders_openapi`, so this file stays a route.
"""

from http import HTTPStatus
from typing import Annotated

from fastapi import APIRouter, Body, Depends

from app.api.deps import PrincipalDep, get_view_render_service
from app.api.feature_gate import require_feature
from app.api.openapi import AUTHENTICATED, problem_responses
from app.api.v1.view_renders_openapi import CREATED, DOCUMENTED, REQUEST_EXAMPLES
from app.schemas.view_renders import MAX_RENDERS, ViewRenderBatch, ViewRenderBatchResult
from app.services.view_render_service import ViewRenderService

router = APIRouter(prefix="/v1/view-renders", tags=["views"])
RenderDep = Annotated[ViewRenderService, Depends(get_view_render_service)]
BatchBody = Annotated[ViewRenderBatch, Body(openapi_examples=REQUEST_EXAMPLES)]


@router.post(
    "",
    response_model=DOCUMENTED,
    response_model_exclude_none=True,
    status_code=HTTPStatus.CREATED,
    operation_id="create_view_render_batch",
    summary="Render several projections in one batch",
    description=(
        "Creates a batch of renders and answers its results inline: up to "
        f"{MAX_RENDERS} `view` / `portfolio_id` / `options` entries, each "
        "rendered over the portfolio it names, in one authentication and one "
        "round trip (ADR-K D-18). **Every entry carries its own `status`**, so "
        "an unknown view (404) or a rejected option (422) fails that entry "
        "alone and the others still render. The batch answers 201 whenever it "
        "was well formed; a malformed or empty body is a 422 and one over the "
        "configured size ceiling a 413, and "
        "no `Location` is returned because the batch is not retrievable. Use "
        "the repeated `?view=` parameter on the portfolio read instead when "
        "every view is over the same portfolio. Spec 0012 AC-4, AC-5, AC-6."
    ),
    responses={**CREATED, **problem_responses(*AUTHENTICATED, 404, 413, 422, 503)},
    dependencies=[require_feature("views.batch-render")],
)
async def create_view_render_batch(
    principal: PrincipalDep, service: RenderDep, batch: BatchBody
) -> ViewRenderBatchResult:
    """Render every entry of the batch, each reporting its own status."""
    return await service.render_batch(principal, batch=batch)


__all__ = ["router"]
