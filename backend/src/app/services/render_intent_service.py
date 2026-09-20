"""The agent's entry point into the registry (ADR-K D-11/D-12, 0005 AC-9).

The model **picks**, it does not invent: a render intent is validated against
the same registry and the same options models the HTTP path uses. An unknown
view, an undeclared option or an out-of-range value is rejected, the rejection
is recorded through the injected ``ErrorReporter``, and the turn falls back to
the endpoint's default projection so the conversation still shows something.

No HTTP surface of its own — GGU-47 calls this from the agent turn. That is
deliberate: the fallback is a *conversation* behaviour, while a client asking
for a bad option should still get its 422.
"""

from typing import Final

from app.core.errors import AppError
from app.core.principal import Principal
from app.core.protocols import ErrorReporter
from app.presentation.fragments import ProjectionDto
from app.schemas.render_intent import RenderedIntent, RenderIntent
from app.schemas.views import DEFAULT_VIEW
from app.services.view_service import ViewService

REJECTED_METRIC: Final[str] = "presentation.render_intent.rejected"


class RenderIntentService:
    """Render what the model asked for, or the default with the reason why."""

    def __init__(self, *, views: ViewService, reporter: ErrorReporter) -> None:
        """Create the service over the shared view service and telemetry."""
        self._views = views
        self._reporter = reporter

    async def render(
        self, principal: Principal, intent: RenderIntent, *, default: str = DEFAULT_VIEW
    ) -> RenderedIntent:
        """Resolve a render intent against the registry (spec 0005 AC-9).

        Args:
            principal: The authenticated caller whose portfolio is read.
            intent: The view the model picked and the options it filled.
            default: The endpoint's documented default, used on rejection.

        Returns:
            The rendered payload with its A2UI surface, plus the rejection
            reason when the model's choice was refused.
        """
        portfolio = await self._views.portfolio(principal)
        try:
            payload = self._views.render_one(
                portfolio, view=intent.view, options=intent.options
            )
        except AppError as exc:
            self._reporter.increment(REJECTED_METRIC, tags={"view": intent.view})
            fallback = self._views.render_one(portfolio, view=default, options={})
            return self._result(default, fallback, rejection=exc.detail)
        return self._result(intent.view, payload, rejection=None)

    def _result(
        self, view: str, payload: ProjectionDto, *, rejection: str | None
    ) -> RenderedIntent:
        """Package a payload with its surface and the rejection, if any."""
        return RenderedIntent(
            view=view,
            payload=payload,
            surface=self._views.surface(view, payload),
            rejection=rejection,
        )


__all__ = ["REJECTED_METRIC", "RenderIntentService"]
