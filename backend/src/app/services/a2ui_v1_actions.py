"""A v1.0 ``action`` becomes the prompt of a turn (ADR-M D-7).

The resolution is v0.9's, untouched: ``SurfaceActionService`` looks the action
up, validates its arguments against the action's own model, records telemetry
and composes the sentence the turn runs (spec 0022). Only the vocabulary
differs. v1.0 names an action with a UAX #31 identifier, so
``drill.attribution.v1`` travels as ``drill_attribution`` — derived from the
registered id, never listed, so the next action needs no edit here.

The refusals are v0.9's too (``a2a_actions``): no third error shape.
"""

from app.actions.registry import ACTIONS
from app.core.principal import Principal
from app.schemas.a2a import INVALID_PARAMS
from app.schemas.a2a_parts import ActionData
from app.schemas.a2ui_v1_events import ActionEvent
from app.services.a2a_actions import REFUSALS, UNKNOWN_ACTION, action_failure
from app.services.a2a_dispatch import failure
from app.services.surface_action_service import SurfaceActionService


def v1_name(action_id: str) -> str:
    """Return the v1.0 name of a registered action id.

    ``drill.attribution.v1`` → ``drill_attribution``: the version is dropped
    (the catalog id carries it) and the separators become underscores.
    """
    return "_".join(action_id.split(".")[:-1]).replace("-", "_")


def action_id_for(name: str) -> str | None:
    """Return the registered action id a v1.0 name stands for, if any."""
    return next(
        (action.id for action in ACTIONS.all() if v1_name(action.id) == name), None
    )


async def action_prompt(
    actions: SurfaceActionService,
    *,
    principal: Principal,
    event: ActionEvent,
    rpc_id: str | int | None,
    request_id: str,
) -> str | dict[str, object]:
    """Return the prompt this action runs, or the JSON-RPC failure body.

    Args:
        actions: The v0.9 dispatcher, which owns the resolution.
        principal: The authenticated caller the turn runs as.
        event: The action the renderer reported.
        rpc_id: The JSON-RPC request id, echoed in a failure.
        request_id: Correlation id, for an audited action's event.

    Returns:
        The server-composed sentence, or the refusal — before any stream
        opens, as on v0.9 (spec 0022 AC-4).
    """
    action_id = action_id_for(event.name)
    if action_id is None:
        return failure(rpc_id, INVALID_PARAMS, UNKNOWN_ACTION)
    data = ActionData(action=action_id, args=event.context)
    try:
        return await actions.prompt_for(principal, data, request_id=request_id)
    except REFUSALS as exc:
        return action_failure(rpc_id, exc)


__all__ = ["action_id_for", "action_prompt", "v1_name"]
