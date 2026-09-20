"""The agent's entry point into the registry (ADR-K D-11/D-12, 0005 AC-9).

The model **picks**, it does not invent: a render intent is validated against
the same registry and the same options models the HTTP path uses. An unknown
view, an undeclared option or an out-of-range value is rejected, the rejection
is recorded through the injected ``ErrorReporter``, and the turn falls back to
the endpoint's default projection so the conversation still shows something.

No HTTP surface of its own — the agent turn calls it, through
``app.services.agent_renders.TurnRenderResolver`` (GGU-84). That is
deliberate: the fallback is a *conversation* behaviour, while a client asking
for a bad option should still get its 422.

**Two entry points, one verdict.** ``accept`` is the judgement — registry,
options model, metric, fallback — and needs no portfolio. ``render`` is that
same verdict followed by the payload, for the caller that wants pixels. The
turn uses ``accept``: it validates every surface without reading a portfolio
per intent, and the payload is the client's own request (GGU-78).
"""

from collections.abc import Mapping
from typing import Any, Final

from app.core.errors import AppError
from app.core.principal import Principal
from app.core.protocols import ErrorReporter
from app.presentation.fragments import ProjectionDto
from app.schemas.render_intent import AcceptedIntent, RenderedIntent, RenderIntent
from app.schemas.views import DEFAULT_VIEW
from app.services.view_service import ViewService

REJECTED_METRIC: Final[str] = "presentation.render_intent.rejected"


class RenderIntentService:
    """Render what the model asked for, or the default with the reason why."""

    def __init__(self, *, views: ViewService, reporter: ErrorReporter) -> None:
        """Create the service over the shared view service and telemetry."""
        self._views = views
        self._reporter = reporter

    def accept(
        self,
        *,
        view: str,
        options: Mapping[str, Any],
        default: str = DEFAULT_VIEW,
    ) -> AcceptedIntent:
        """Judge the model's choice against the registry (spec 0005 AC-9).

        Args:
            view: The projection id the model picked; never trusted.
            options: The options it filled, judged by the projection's own
                bounded model — an unknown one is a rejection, not a shrug.
            default: The endpoint's documented default, used on rejection.

        Returns:
            The view and options that may be used, plus the reason the
            model's choice was refused when it was. Refusal is recorded
            through the reporter and never raised: a bad guess must not end
            a turn (ADR-K D-12).
        """
        try:
            self._views.validate(view=view, options=options)
        except AppError as exc:
            self._reporter.increment(REJECTED_METRIC, tags={"view": view})
            return AcceptedIntent(view=default, rejection=exc.detail)
        return AcceptedIntent(view=view, options=dict(options))

    async def render(
        self, principal: Principal, intent: RenderIntent, *, default: str = DEFAULT_VIEW
    ) -> RenderedIntent:
        """Render what the model asked for, or the default (spec 0005 AC-9).

        Args:
            principal: The authenticated caller whose portfolio is read.
            intent: The view the model picked and the options it filled.
            default: The endpoint's documented default, used on rejection.

        Returns:
            The rendered payload with its A2UI surface, plus the rejection
            reason when the model's choice was refused.
        """
        accepted = self.accept(
            view=intent.view, options=intent.options, default=default
        )
        portfolio = await self._views.portfolio(principal)
        payload = self._views.render_one(
            portfolio, view=accepted.view, options=accepted.options
        )
        return self._result(accepted.view, payload, rejection=accepted.rejection)

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
