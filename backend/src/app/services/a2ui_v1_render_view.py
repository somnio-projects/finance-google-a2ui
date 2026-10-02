"""``callAgentFunction("renderView")``: an edit, answered without the model (D-6).

A renderer re-renders a component — another range, another lot method — by
calling the catalog's one function. Nothing here reaches ``AgentService``: the
view and its options are judged by the registry and the projection's own
options model (ADR-K D-3), the payload is rendered by the same ``ViewService``
the REST read uses, and the answer is two messages:
``agentFunctionResponse{value:{componentId, view}}`` then
``updateDataModel{path:"/<componentId>", value:{view, options, payload}}``.

A refusal is an ``agentFunctionResponse`` with an error, not a JSON-RPC error:
the call was well formed, the function said no. The telemetry tag is the
refusal's code, never an argument value (spec 0053 §5).
"""

from typing import Final

from pydantic import ValidationError

from app.core.protocols import ErrorReporter
from app.presentation.a2ui_v1.messages import (
    Message,
    bound,
    function_error,
    function_value,
    update_data_model,
)
from app.presentation.a2ui_v1.option_errors import options_rejection
from app.presentation.a2ui_v1.wire import (
    CATALOG_ID,
    INVALID_FUNCTION_CALL,
    RENDER_VIEW,
    UNKNOWN_FUNCTION,
)
from app.presentation.errors import UnknownViewError
from app.presentation.registry import ProjectionRegistry
from app.schemas.a2ui_v1_events import CallAgentFunction
from app.schemas.a2ui_v1_render_view import RenderViewArgs
from app.services.a2ui_v1_payloads import PayloadRenderer

ACCEPTED_METRIC: Final[str] = "a2ui.render_view.accepted"
REJECTED_METRIC: Final[str] = "a2ui.render_view.rejected"

NOT_DEFINED: Final[str] = f"This catalog defines one function, {RENDER_VIEW}."
BAD_ARGUMENTS: Final[str] = f"{RENDER_VIEW} takes componentId, view and options."
UNKNOWN_VIEW: Final[str] = "The view is not registered in this catalog."


class RenderViewService:
    """Answer a renderer's ``renderView`` call, deterministically."""

    def __init__(
        self,
        *,
        registry: ProjectionRegistry,
        payloads: PayloadRenderer,
        reporter: ErrorReporter,
    ) -> None:
        """Bind the handler to the registry, the renderer and telemetry."""
        self._registry = registry
        self._payloads = payloads
        self._reporter = reporter

    async def answer(self, call: CallAgentFunction) -> list[Message]:
        """Run one function call and return the messages that answer it.

        Args:
            call: The validated ``callAgentFunction``.

        Returns:
            The value and the data-model update, or a single error response.
        """
        judged = self._judge(call)
        if not isinstance(judged, RenderViewArgs):
            self._reporter.increment(REJECTED_METRIC, tags={"code": judged[0]})
            return [function_error(call.function_call_id, *judged)]
        rendered = await self._payloads.render(
            index=0, view=judged.view, options=judged.options
        )
        self._reporter.increment(ACCEPTED_METRIC, tags={"view": judged.view})
        return [
            function_value(
                call.function_call_id,
                {"componentId": judged.component_id, "view": judged.view},
            ),
            update_data_model(
                call.surface_id,
                f"/{judged.component_id}",
                bound(rendered.view, rendered.options, rendered.payload),
            ),
        ]

    def _judge(self, call: CallAgentFunction) -> RenderViewArgs | tuple[str, str]:
        """Return the accepted arguments, or the ``(code, message)`` refusal."""
        function = call.call_function
        if function.call != RENDER_VIEW or function.catalog_id not in {
            None,
            CATALOG_ID,
        }:
            return UNKNOWN_FUNCTION, NOT_DEFINED
        try:
            args = RenderViewArgs.model_validate(function.args)
            projection = self._registry.get(args.view)
        except ValidationError:
            return INVALID_FUNCTION_CALL, BAD_ARGUMENTS
        except UnknownViewError:
            return INVALID_FUNCTION_CALL, UNKNOWN_VIEW
        rejection = options_rejection(projection, args.options)
        if rejection is not None:
            return INVALID_FUNCTION_CALL, rejection
        return args


__all__ = [
    "ACCEPTED_METRIC",
    "BAD_ARGUMENTS",
    "NOT_DEFINED",
    "REJECTED_METRIC",
    "UNKNOWN_VIEW",
    "RenderViewService",
]
