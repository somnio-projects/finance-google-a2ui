"""The v1.0 messages this agent sends, and the A2A part that carries them.

Builders only: every function returns the JSON object the wire carries, and
none of them decides anything. Which surface to open, what payload goes into it
and which function call is being answered is the services' business; here is
only the shape the vendored schemas and ``docs/a2ui/v1.0/examples/`` pin.
"""

from collections.abc import Iterable, Mapping, Sequence
from typing import Any

from app.presentation.a2ui_v1.wire import CATALOG_ID, MESSAGE_VERSION, MIME_TYPE

#: One v1.0 message: ``{"version": "v1.0", "<kind>": {...}}``.
Message = dict[str, Any]


def _message(kind: str, body: Mapping[str, Any]) -> Message:
    """Wrap one message body in its versioned envelope."""
    return {"version": MESSAGE_VERSION, kind: dict(body)}


def bound(
    view: str, options: Mapping[str, Any], payload: Mapping[str, Any]
) -> dict[str, Any]:
    """Return what one component binds: ``{view, options, payload}`` (D-3).

    Args:
        view: The projection the payload was rendered from.
        options: The options it was rendered with, as the caller gave them.
        payload: The DTO, exactly as the REST read serves it.
    """
    return {"view": view, "options": dict(options), "payload": dict(payload)}


def create_surface(
    surface_id: str,
    components: Sequence[Mapping[str, Any]],
    data_model: Mapping[str, Any],
) -> Message:
    """Open a surface with its components and its data model inline (D-3).

    Args:
        surface_id: ``<taskId>-<index>`` — unique for the renderer's lifetime.
        components: The adjacency list, ``root`` first.
        data_model: One ``{view, options, payload}`` per component, keyed by
            the component id each one binds.
    """
    return _message(
        "createSurface",
        {
            "surfaceId": surface_id,
            "catalogId": CATALOG_ID,
            "components": [dict(component) for component in components],
            "dataModel": dict(data_model),
        },
    )


def update_data_model(surface_id: str, path: str, value: Mapping[str, Any]) -> Message:
    """Replace the value at ``path`` in a surface's data model (D-6)."""
    return _message(
        "updateDataModel", {"surfaceId": surface_id, "path": path, "value": dict(value)}
    )


def function_value(call_id: str, value: Mapping[str, Any]) -> Message:
    """Answer a ``callAgentFunction`` with its return value."""
    return _message(
        "agentFunctionResponse", {"functionCallId": call_id, "value": dict(value)}
    )


def function_error(call_id: str, code: str, message: str) -> Message:
    """Answer a ``callAgentFunction`` with an error.

    Args:
        call_id: The id the renderer sent, copied back.
        code: ``INVALID_FUNCTION_CALL`` or ``UNKNOWN_FUNCTION``.
        message: One or two safe sentences; never the caller's own values.
    """
    return _message(
        "agentFunctionResponse",
        {"functionCallId": call_id, "error": {"code": code, "message": message}},
    )


def data_part(messages: Iterable[Message]) -> dict[str, Any]:
    """Carry v1.0 messages in one A2A ``DataPart`` (extension spec, *Data encoding*).

    Returns:
        ``{kind: "data", metadata: {mimeType}, data: [...]}``; ``data`` is
        always a list, processed in order by the renderer.
    """
    return {"kind": "data", "metadata": {"mimeType": MIME_TYPE}, "data": list(messages)}


__all__ = [
    "Message",
    "bound",
    "create_surface",
    "data_part",
    "function_error",
    "function_value",
    "update_data_model",
]
