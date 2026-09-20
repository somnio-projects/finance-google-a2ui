"""Portfolio projections controller — one request, several rendered views.

The response model and its examples are built **from the registry** at import
time (``app.presentation.contract``), so a projection added under
``presentation/views/`` appears in this operation's ``oneOf`` and in its
examples without this file changing (ADR-K D-15).
"""

from typing import Annotated, Any, Final

from fastapi import APIRouter, Depends, Path, Query, Response
from pydantic import BaseModel

from app.api.caching import NOT_MODIFIED_RESPONSE, ConditionalDep, strong_etag
from app.api.deps import PrincipalDep, get_view_service
from app.api.feature_gate import require_feature
from app.api.openapi import AUTHENTICATED, problem_responses
from app.presentation.contract import response_examples, views_response_model
from app.presentation.registry import REGISTRY
from app.presentation.sample import EXAMPLE_AS_OF
from app.presentation.views import LOADED
from app.schemas.views import (
    CURRENT_PORTFOLIO,
    DEFAULT_VIEW,
    MAX_VIEWS,
    PortfolioViewsResponse,
    ViewQuery,
)
from app.services.view_service import ViewService

router = APIRouter(prefix="/v1/portfolios", tags=["views"])
ViewsDep = Annotated[ViewService, Depends(get_view_service)]
PortfolioId = Annotated[
    str,
    Path(
        max_length=64,
        pattern=r"^[a-z0-9-]{1,64}$",
        description=(
            "Portfolio to read. Only the well-known `current` exists today: "
            "it resolves to the authenticated caller's own portfolio."
        ),
        examples=[CURRENT_PORTFOLIO],
    ),
]

#: Built from the registry — ``LOADED`` is what guarantees it is populated.
VIEWS: Final[tuple[str, ...]] = LOADED
DOCUMENTED: Final[type[BaseModel]] = views_response_model(
    REGISTRY.all(), name="PortfolioViews"
)
SUCCESS: Final[dict[int | str, dict[str, Any]]] = {
    200: {
        "description": "One rendered projection per requested view.",
        "content": {
            "application/json": {
                "examples": response_examples(
                    REGISTRY.all(),
                    as_of=EXAMPLE_AS_OF.isoformat().replace("+00:00", "Z"),
                    portfolio_id=CURRENT_PORTFOLIO,
                )
            }
        },
    }
}


@router.get(
    "/{portfolio_id}/views",
    response_model=DOCUMENTED,
    operation_id="read_portfolio_views",
    summary="Render one or more projections of a portfolio",
    description=(
        "Renders the requested projections over one read of the caller's "
        f"portfolio and answers a keyed object — repeat `view` for up to "
        f"{MAX_VIEWS} projections in a single round trip (ADR-K D-17). With no "
        f"`view`, the documented selection rule picks one from the data and "
        f"falls back to `{DEFAULT_VIEW}`. Options are shared, declared and "
        "bounded: an undeclared query parameter, an out-of-range value or an "
        "option the requested projection does not declare answers 422, and an "
        "unknown view id answers 404. Spec 0005 AC-6, AC-7, AC-10."
    ),
    responses={
        **SUCCESS,
        **NOT_MODIFIED_RESPONSE,
        **problem_responses(*AUTHENTICATED, 404, 422, 503),
    },
    dependencies=[require_feature("views.read")],
)
async def read_portfolio_views(
    portfolio_id: PortfolioId,
    query: Annotated[ViewQuery, Query()],
    principal: PrincipalDep,
    service: ViewsDep,
    conditional: ConditionalDep,
) -> PortfolioViewsResponse | Response:
    """Render every requested projection in one round trip. Spec 0005 AC-6.

    The body is a pure function of the subject, the portfolio, the views, the
    options and ``as_of``, so it carries a strong ``ETag`` built from exactly
    those and revalidates to 304 (ADR-K D-20, spec 0012 AC-7).
    """
    body = await service.render(
        principal, portfolio_id=portfolio_id, query=query, default=DEFAULT_VIEW
    )
    etag = strong_etag(
        "portfolio-views",
        principal.subject,
        portfolio_id,
        sorted(body.views),
        query.options(),
        body.as_of,
    )
    return conditional.resolve(body, etag=etag)


__all__ = ["DOCUMENTED", "VIEWS", "router"]
