"""The turn's call site into the registry (ADR-K D-11/D-12, GGU-84).

A tool hands the loop a render intent; this is what stands between that intent
and the client. It is the seam ``RenderIntentService`` was written for and
never had: until GGU-84 the only thing a tool-emitted view id met was
``VIEW_ID_SHAPE``, a regex on the string, which ``totally.invented.v9``
satisfies — and options were never looked at.

**Two shapes, one authority.** The agent host speaks
``app.agent.contracts.RenderIntent`` (view + options, nothing rendered) and the
presentation layer speaks the registry. Translating between them is all this
module does; the judging — registry lookup, the projection's own options
model, the ``REJECTED_METRIC`` and the fallback — belongs to
``RenderIntentService`` and stays there, so the model's path and the client's
``?view=`` path cannot drift apart.

**A rejection never fails the turn** (ADR-K D-12). The model guessing badly is
a normal event: the default projection is substituted, the metric is recorded,
and the conversation still shows something.
"""

from app.agent.contracts import RenderIntent
from app.schemas.views import DEFAULT_VIEW
from app.services.render_intent_service import RenderIntentService


class TurnRenderResolver:
    """Replace a tool's render intent with one the registry accepts."""

    def __init__(
        self, *, intents: RenderIntentService, default: str = DEFAULT_VIEW
    ) -> None:
        """Bind the resolver to the registry entry point and the fallback.

        Args:
            intents: The service that judges an intent against the registry.
            default: The endpoint's documented default projection, served
                when the model's choice is refused (ADR-K D-12).
        """
        self._intents = intents
        self._default = default

    def resolve(self, intent: RenderIntent) -> RenderIntent:
        """Return the intent the client may act on.

        Args:
            intent: What the tool asked for, unvalidated.

        Returns:
            The same intent when the registry accepts it, otherwise one
            naming the default projection with no options. Never raises: a
            refused choice is answered, not propagated.
        """
        accepted = self._intents.accept(
            view=intent.view, options=intent.options, default=self._default
        )
        return RenderIntent(view=accepted.view, options=accepted.options)


__all__ = ["TurnRenderResolver"]
