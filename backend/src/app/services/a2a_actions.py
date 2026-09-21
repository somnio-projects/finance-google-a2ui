"""Where a `data` part becomes a prompt, or a JSON-RPC error (spec 0022 §3.2).

The action half of the protocol adapter, beside ``a2a_dispatch`` rather than
inside it: that module answers *which method was called*, this one answers
*what this surface asked us to run*. Both keep the branching out of the
controller (ADR-J D-2).

**No third error shape.** A client already parses two — RFC 9457 before the
envelope, JSON-RPC inside it — and GGU-78 names a third as the harm to avoid.
So a refused action reuses the codes that exist: a disabled capability is a
method that does not exist, and everything else is invalid params.

Resolution happens **before the stream opens**, so a bad action is a clean
error object rather than a stream whose first event is a failure (AC-4), and
rejection is terminal: unlike an invalid render intent there is no sensible
default to fall back to, and running a different turn than the one the user
tapped is worse than saying no.
"""

from typing import Final

from app.actions.errors import UnknownActionError
from app.core.errors import (
    AppError,
    FeatureDisabledError,
    ValidationFailedError,
)
from app.core.principal import Principal
from app.schemas.a2a import INVALID_PARAMS, METHOD_NOT_FOUND, ClientMessage
from app.services.a2a_dispatch import failure
from app.services.surface_action_service import SurfaceActionService

#: The refusals this surface translates. Anything else is infrastructure
#: failure and must not be dressed up as a client mistake.
REFUSALS: Final[tuple[type[AppError], ...]] = (
    FeatureDisabledError,
    UnknownActionError,
    ValidationFailedError,
)
UNKNOWN_ACTION: Final[str] = "UNKNOWN_ACTION"
ACTIONS_DISABLED: Final[str] = "Surface actions are not enabled."


def action_failure(request_id: str | int | None, exc: AppError) -> dict[str, object]:
    """Map a refused surface action onto the error shapes that already exist.

    Args:
        request_id: The id to echo, so the client can correlate.
        exc: What the dispatcher raised while resolving the action.

    Returns:
        The JSON-RPC error body to answer with, at HTTP 200.

    Note:
        ``exc.detail`` is used only for an argument fault, where the actions
        package has already reduced the message to a registered action id and
        **declared** argument names. Nothing the caller wrote is echoed — the
        rule ``a2a_dispatch``'s docstring records, applied to a second path.
    """
    if isinstance(exc, FeatureDisabledError):
        return failure(request_id, METHOD_NOT_FOUND, ACTIONS_DISABLED)
    if isinstance(exc, UnknownActionError):
        return failure(request_id, INVALID_PARAMS, UNKNOWN_ACTION)
    return failure(request_id, INVALID_PARAMS, exc.detail)


async def prepared_prompt(
    actions: SurfaceActionService,
    *,
    principal: Principal,
    message: ClientMessage,
    rpc_id: str | int | None,
    request_id: str,
) -> str | dict[str, object]:
    """Return the prompt this call runs, or the failure body to answer with.

    Args:
        actions: The dispatcher that resolves an action against the registry.
        principal: The authenticated caller the turn runs as.
        message: The client's message, already validated.
        rpc_id: The JSON-RPC request id, echoed in a failure.
        request_id: Correlation id, for an audited action's event.

    Returns:
        The turn's input — the user's prose, or the sentence the **backend**
        composed for a registered action — or the JSON-RPC error body.
    """
    data = message.action()
    if data is None:
        return message.text()
    try:
        return await actions.prompt_for(principal, data, request_id=request_id)
    except REFUSALS as exc:
        # Deliberately NOT `AppError`. A DependencyUnavailableError from the
        # audit write of an `audited=True` action is a 503, and catching it
        # here would report infrastructure trouble as invalid params *and*
        # put its detail on the wire. It belongs to the 500 handler, which
        # masks it. Nothing declares `audited=True` today; this is the seam
        # being kept honest before the first action that does.
        return action_failure(rpc_id, exc)


__all__ = ["ACTIONS_DISABLED", "UNKNOWN_ACTION", "action_failure", "prepared_prompt"]
