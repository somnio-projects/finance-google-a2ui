"""What a v1.0 renderer reads first: the card and the catalog (ADR-M D-5, D-8).

The card is public, like the v0.9 one, because nothing can hold a token before
it has read where to get one (spec 0010 OD-1); it carries no subject data. The
catalog is behind the bearer token like every other read: a renderer fetches
it after it has signed in, and the copy it ships with is the checked-in file
these bytes are generated from.
"""

from typing import Annotated

from fastapi import APIRouter, Depends, Response

from app.api.a2ui_v1.openapi_shapes import CATALOG_RESPONSE
from app.api.caching import (
    CACHE_CONTROL,
    NOT_MODIFIED_RESPONSE,
    VARY,
    ConditionalDep,
    strong_etag,
)
from app.api.deps import get_current_principal
from app.api.deps.a2ui_v1 import get_v1_agent_card, get_v1_catalog
from app.api.openapi import problem_responses
from app.schemas.a2ui_v1_card import V1AgentCard

router = APIRouter(tags=["a2a"])

CardDep = Annotated[V1AgentCard, Depends(get_v1_agent_card)]
CatalogDep = Annotated[str, Depends(get_v1_catalog)]


@router.get(
    "/.well-known/agent-card.json",
    response_model=V1AgentCard,
    response_model_by_alias=True,
    operation_id="read_a2ui_v1_agent_card",
    summary="Describe the A2UI v1.0 agent to a renderer",
    description=(
        "The v1.0 bootstrap document (ADR-M D-8, spec 0053): the same agent "
        "as `/.well-known/agent-card.json`, advertised on `/a2ui/v1/a2a` with "
        "`protocolVersion` 1.0 and the A2UI v1.0 extension, whose params name "
        "the finance catalog id. **Unauthenticated by contract**, like the "
        "v0.9 card."
    ),
    responses=problem_responses(429, 500),
)
def v1_agent_card(card: CardDep) -> V1AgentCard:
    """Return the v1.0 card."""
    return card


@router.get(
    "/catalog",
    dependencies=[Depends(get_current_principal)],
    response_model=None,
    operation_id="read_a2ui_v1_catalog",
    summary="Read the generated A2UI v1.0 catalog",
    description=(
        "The finance catalog a v1.0 renderer draws from (ADR-M D-5, spec "
        "0053): one component per projection family plus `Section`, the "
        "composition rules, the `renderView` function and the model's "
        "instructions. Byte for byte `docs/a2ui/v1.0/finance.catalog.json`, "
        "which `make catalog` generates from the projection registry. "
        "Requires a bearer token."
    ),
    responses={
        200: CATALOG_RESPONSE,
        **NOT_MODIFIED_RESPONSE,
        **problem_responses(401, 429, 500),
    },
)
def v1_catalog(document: CatalogDep, conditional: ConditionalDep) -> Response:
    """Return the catalog document as served bytes, revalidated by ETag."""
    etag = strong_etag(document)
    answer = conditional.resolve(document, etag=etag)
    if isinstance(answer, Response):
        return answer
    validators = {"ETag": etag, "Cache-Control": CACHE_CONTROL, "Vary": VARY}
    return Response(content=answer, media_type="application/json", headers=validators)


__all__ = ["router"]
