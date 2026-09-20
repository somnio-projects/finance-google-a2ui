"""The heterogeneous batch render, entry by entry (ADR-K D-18, spec 0012).

Separate from ``ViewService`` because it answers a different question: that
service renders *one caller's request*, this one renders *a list of them and
survives the bad ones*. It owns no shaping and no registry knowledge — it
delegates each entry to ``ViewService`` and only decides what happens when an
entry raises.

**Failure is per entry, by construction.** ``AppError`` already carries the
status and the safe code each projection failure deserves, so an entry is
turned into a problem document here instead of being allowed to abort the
batch. Anything that is *not* an ``AppError`` is a defect, not a rejected
entry, and is deliberately left to propagate to the 500 handler.
"""

from http import HTTPStatus

from app.core.errors import PROBLEM_TYPE_BASE, AppError
from app.core.principal import Principal
from app.schemas.problem import ProblemDetails
from app.schemas.view_renders import (
    ViewRenderBatch,
    ViewRenderBatchResult,
    ViewRenderRequest,
    ViewRenderResult,
)
from app.services.view_service import ViewService


class ViewRenderService:
    """Render every entry of a batch, reporting each one's outcome on its own."""

    def __init__(self, *, views: ViewService) -> None:
        """Create the service over the shared projection renderer."""
        self._views = views

    async def render_batch(
        self, principal: Principal, *, batch: ViewRenderBatch
    ) -> ViewRenderBatchResult:
        """Render every entry, in order, without letting one failure spread.

        Args:
            principal: The authenticated caller; every entry reads only this
                subject's portfolios, whatever id it names.
            batch: The validated entries to render.

        Returns:
            One result per entry, in request order, each carrying either a
            rendered payload or the problem that entry alone produced.
        """
        return ViewRenderBatchResult(
            results=[
                await self._render_one(principal, entry) for entry in batch.renders
            ]
        )

    async def _render_one(
        self, principal: Principal, entry: ViewRenderRequest
    ) -> ViewRenderResult:
        """Render one entry, or describe why it could not be rendered."""
        try:
            portfolio = await self._views.portfolio(
                principal, portfolio_id=entry.portfolio_id
            )
            payload = self._views.render_one(
                portfolio, view=entry.view, options=entry.options
            )
        except AppError as exc:
            return ViewRenderResult(
                status=exc.status.value,
                view=entry.view,
                portfolio_id=entry.portfolio_id,
                error=_problem(exc),
            )
        return ViewRenderResult(
            status=HTTPStatus.OK.value,
            view=entry.view,
            portfolio_id=entry.portfolio_id,
            as_of=portfolio.as_of,
            payload=payload,
        )


def _problem(exc: AppError) -> ProblemDetails:
    """Describe one failed entry as an RFC 9457 problem document.

    Args:
        exc: The typed error the projection path raised.

    Returns:
        The problem body. ``instance`` and ``request_id`` are left out on
        purpose: they belong to the batch request, which carries them in the
        response header, not to an entry inside it.
    """
    return ProblemDetails(
        type=f"{PROBLEM_TYPE_BASE}{exc.code}",
        title=exc.status.phrase,
        status=exc.status.value,
        detail=exc.detail,
    )


__all__ = ["ViewRenderService"]
