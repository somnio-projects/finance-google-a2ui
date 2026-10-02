"""The request bodies ``POST /a2ui/v1/a2a`` documents (spec 0053 §3).

Split from ``openapi_shapes`` under the 150-line budget: these are what a
renderer *sends*, that module is what it gets back. Both are built from the
wire constants, never transcribed.
"""

from typing import Any, Final

from app.presentation.a2ui_v1.wire import (
    CAPABILITIES_KEY,
    CATALOG_ID,
    MESSAGE_VERSION,
    MIME_TYPE,
)

#: The task id the documented examples share, so a request and its stream
#: read as one exchange.
TASK: Final[str] = "7b1e"
_CAPABILITIES: Final[dict[str, Any]] = {
    "a2uiRendererCapabilities": {
        CAPABILITIES_KEY: {"supportedCatalogIds": [CATALOG_ID]}
    }
}


def _call(part: dict[str, Any]) -> dict[str, Any]:
    """Wrap one message part in a ``message/stream`` envelope."""
    return {
        "jsonrpc": "2.0",
        "id": "req-1",
        "method": "message/stream",
        "params": {
            "message": {"role": "user", "parts": [part], "metadata": _CAPABILITIES}
        },
    }


def _renderer_part(message: dict[str, Any]) -> dict[str, Any]:
    """Wrap one renderer-to-agent message in its A2UI data part."""
    return {"kind": "data", "metadata": {"mimeType": MIME_TYPE}, "data": [message]}


REQUEST_EXAMPLES: Final[dict[str, dict[str, Any]]] = {
    "prose": {
        "summary": "A question: an ordinary turn",
        "value": _call({"kind": "text", "text": "What moved my portfolio today?"}),
    },
    "renderView": {
        "summary": "An edit: renderView, answered without the model",
        "value": _call(
            _renderer_part(
                {
                    "version": MESSAGE_VERSION,
                    "callAgentFunction": {
                        "surfaceId": f"{TASK}-0",
                        "functionCallId": "call-01",
                        "callFunction": {
                            "call": "renderView",
                            "args": {
                                "componentId": "root",
                                "view": "portfolio.summary.v1",
                                "options": {"range": "1y"},
                            },
                        },
                    },
                }
            )
        ),
    },
}


__all__ = ["REQUEST_EXAMPLES", "TASK"]
