"""Render the payload a v1.0 surface binds, through the REST path (ADR-M D-3).

The v0.9 turn never renders: it validates an intent and lets the client fetch
the payload over REST (GGU-78). v1.0 puts the payload on the wire, so the turn
must render it — and it does so through the **same** ``ViewService`` that
answers ``GET /v1/portfolios/current/views``, with the same options model and
the same portfolio read, so a figure on a v1.0 surface is the figure the REST
read serves (spec 0053 AC-3).

The portfolio is read once per request, however many surfaces the turn draws.
"""

from collections.abc import Mapping
from typing import Any

from app.core.principal import Principal
from app.domain.portfolio import Portfolio
from app.presentation.a2ui_v1.surfaces import RenderedView
from app.services.view_service import ViewService


class PayloadRenderer:
    """Render a validated view for one caller, reading their portfolio once."""

    def __init__(self, *, views: ViewService, principal: Principal) -> None:
        """Bind the renderer to the request's view service and caller."""
        self._views = views
        self._principal = principal
        self._portfolio: Portfolio | None = None

    async def render(
        self, *, index: int, view: str, options: Mapping[str, Any]
    ) -> RenderedView:
        """Render ``view`` with ``options`` and name the component that draws it.

        Args:
            index: The view's position in the turn.
            view: A registered projection id.
            options: Options the registry has already accepted.

        Returns:
            The payload as JSON — serialised as the REST read serialises it —
            with the component its own A2UI adapter names.

        Raises:
            UnknownViewError: When ``view`` is not registered.
            ValidationFailedError: When an option is undeclared or out of range.
        """
        portfolio = await self._read()
        payload = self._views.render_one(portfolio, view=view, options=options)
        return RenderedView(
            index=index,
            component=self._views.surface(view, payload).component,
            view=view,
            options=dict(options),
            payload=payload.model_dump(mode="json", by_alias=True),
        )

    async def _read(self) -> Portfolio:
        """Return the caller's portfolio, reading it on first use only."""
        if self._portfolio is None:
            self._portfolio = await self._views.portfolio(self._principal)
        return self._portfolio


__all__ = ["PayloadRenderer"]
