"""Decide what one v1.0 call asks for, or why it cannot be answered (ADR-M D-8).

The v1.0 half of ``a2a_dispatch``: the envelope is parsed by that module's
``parse`` and refused with its ``failure``, so a client of both surfaces sees
one JSON-RPC error vocabulary. What is new is the **negotiation**: a renderer
that does not declare the finance catalog in ``a2uiRendererCapabilities`` is
refused with an error naming the catalog — before a turn runs, and never in
prose (spec 0053 AC-7).

Every message is a fixed string, for the reason ``a2a_dispatch`` records.
"""

from typing import Final

from pydantic import ValidationError

from app.presentation.a2ui_v1.wire import CATALOG_ID
from app.schemas.a2a import (
    INVALID_PARAMS,
    METHOD_NOT_FOUND,
    UNSUPPORTED_OPERATION,
    JsonRpcRequest,
)
from app.schemas.a2ui_v1_message import V1ClientMessage, V1StreamParams
from app.services.a2a_dispatch import (
    BAD_PARAMS,
    CANCEL_METHOD,
    CANCEL_UNSUPPORTED,
    STREAM_METHOD,
    UNKNOWN_METHOD,
    failure,
)

#: The refusal a renderer without the finance catalog receives (D-8).
CATALOG_REQUIRED: Final[str] = (
    f"a2uiRendererCapabilities['v1.0'].supportedCatalogIds must include {CATALOG_ID}"
)


def v1_message_of(envelope: JsonRpcRequest) -> V1ClientMessage | dict[str, object]:
    """Return the v1.0 message to answer, or the failure body for this call.

    Args:
        envelope: A validated JSON-RPC envelope.

    Returns:
        The renderer's message when the method is ``message/stream``, its
        parameters validate and it declares the finance catalog; otherwise
        the JSON-RPC error body, at HTTP 200.
    """
    if envelope.method == CANCEL_METHOD:
        return failure(envelope.id, UNSUPPORTED_OPERATION, CANCEL_UNSUPPORTED)
    if envelope.method != STREAM_METHOD:
        return failure(envelope.id, METHOD_NOT_FOUND, UNKNOWN_METHOD)
    try:
        message = V1StreamParams.model_validate(envelope.params).message
    except ValidationError:
        return failure(envelope.id, INVALID_PARAMS, BAD_PARAMS)
    if CATALOG_ID not in message.catalogs():
        return failure(envelope.id, INVALID_PARAMS, CATALOG_REQUIRED)
    return message


__all__ = ["CATALOG_REQUIRED", "v1_message_of"]
