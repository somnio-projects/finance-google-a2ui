"""The one path from a request — or an agent turn — to a rendered view.

Both callers of ADR-K D-11 land here: the HTTP controller with a ``ViewQuery``
and ``RenderIntentService`` with the model's choice. They share the registry,
the options models and the portfolio lookup, so a view id means the same thing
and an option is judged the same way on both paths.

The service performs no shaping of its own. It resolves the portfolio, hands
*(portfolio, options)* to the projection and returns what came back: the
rendering stays pure and unit-testable in ``app.presentation`` (ADR-K D-6).
"""

from collections.abc import Mapping
from typing import Any

from app.core.errors import NotFoundError
from app.core.principal import Principal
from app.domain.portfolio import Portfolio
from app.domain.provider import PortfolioProvider
from app.presentation.fragments import ProjectionDto
from app.presentation.registry import ProjectionRegistry
from app.presentation.resolve import validated_options
from app.presentation.selection import select_view
from app.presentation.surfaces import Surface
from app.schemas.views import (
    CURRENT_PORTFOLIO,
    PortfolioViewsResponse,
    ViewDescriptor,
    ViewQuery,
)


class ViewService:
    """Resolve, validate and render the projections a caller asked for."""

    def __init__(
        self, *, provider: PortfolioProvider, registry: ProjectionRegistry
    ) -> None:
        """Create the service over the process provider and registry."""
        self._provider = provider
        self._registry = registry

    async def catalog(self) -> list[ViewDescriptor]:
        """Describe every registered projection for `/v1/views` (0005 AC-8)."""
        return [
            ViewDescriptor(
                id=projection.id,
                summary=projection.summary,
                endpoints=list(projection.endpoints),
                options_schema=projection.options.model_json_schema(),
                example=dict(projection.example),
            )
            for projection in self._registry.all()
        ]

    async def render(
        self,
        principal: Principal,
        *,
        portfolio_id: str,
        query: ViewQuery,
        default: str,
    ) -> PortfolioViewsResponse:
        """Render every requested view over one portfolio read (0005 AC-6).

        Args:
            principal: The authenticated caller.
            portfolio_id: Which portfolio to read; only ``current`` exists.
            query: The validated, bounded query parameters.
            default: The endpoint's documented default projection id.

        Returns:
            One keyed entry per requested view — or per the selection rule's
            choice when the caller named none.
        """
        portfolio = self.portfolio(principal, portfolio_id=portfolio_id)
        options = query.options()
        chosen = tuple(query.view) or (
            select_view(portfolio, projections=self._registry.all(), default=default),
        )
        return PortfolioViewsResponse(
            as_of=portfolio.as_of,
            portfolio_id=portfolio_id,
            views={
                view: self.render_one(portfolio, view=view, options=options)
                for view in chosen
            },
        )

    def portfolio(
        self, principal: Principal, *, portfolio_id: str = CURRENT_PORTFOLIO
    ) -> Portfolio:
        """Return the caller's own portfolio; only ``current`` is addressable.

        Raises:
            NotFoundError: For any other id — a caller must not be able to
                name another subject's portfolio (spec 0005 §5).
        """
        if portfolio_id != CURRENT_PORTFOLIO:
            msg = f"portfolio {portfolio_id!r} does not exist"
            raise NotFoundError(msg)
        return self._provider.get(principal.subject)

    def render_one(
        self, portfolio: Portfolio, *, view: str, options: Mapping[str, Any]
    ) -> ProjectionDto:
        """Validate ``options`` against ``view`` and render it.

        Raises:
            UnknownViewError: When ``view`` is not registered.
            ValidationFailedError: When an option is undeclared or out of range.
        """
        projection = self._registry.get(view)
        return projection.render(portfolio, validated_options(projection, options))

    def surface(self, view: str, payload: ProjectionDto) -> Surface:
        """Map ``payload`` onto its A2UI surface through the view's adapter."""
        return self._registry.get(view).surface(payload)


__all__ = ["ViewService"]
