"""What ``/a2ui/v1/*`` looks like on the wire, for the OpenAPI document.

As with ``a2a_openapi``: the body is one JSON-RPC envelope for many methods and
the answer is a stream or an error object, so FastAPI derives nothing from the
signature and every example is spelled here. They are **built with the same
builders the route uses** rather than transcribed, so the document cannot
describe a shape the service no longer emits. The canonical, full-size
examples are ``docs/a2ui/v1.0/examples/``.
"""

from typing import Any, Final

from app.api.a2ui_v1.openapi_requests import REQUEST_EXAMPLES
from app.api.a2ui_v1.openapi_requests import TASK as _TASK
from app.presentation.a2ui_v1.messages import bound, create_surface, data_part
from app.presentation.a2ui_v1.wire import CATALOG_ID, PROTOCOL_VERSION
from app.schemas.a2a import JsonRpcFailure, JsonRpcRequest
from app.services.a2a_events import INPUT_REQUIRED, WORKING, sse, status
from app.services.a2ui_v1_events import artifact, closing

EVENT_STREAM: Final[str] = "text/event-stream"
_CONTEXT: Final[str] = "c2f1"
_SURFACE: Final[dict[str, Any]] = data_part(
    [
        create_surface(
            f"{_TASK}-0",
            [
                {
                    "id": "root",
                    "component": "PortfolioSummary",
                    "data": {"path": "/root"},
                    "accessibility": {"label": "Portfolio summary"},
                }
            ],
            {
                "root": bound(
                    "portfolio.summary.v1",
                    {"range": "1d"},
                    {"view": "portfolio.summary.v1"},
                )
            },
        )
    ]
)

STREAM_EXAMPLE: Final[str] = "".join(
    sse(event)
    for event in (
        status(_TASK, _CONTEXT, WORKING),
        artifact(_TASK, _CONTEXT, f"{_TASK}-0", _SURFACE),
        closing(_TASK, _CONTEXT, "Your portfolio is up today.", ()),
        status(_TASK, _CONTEXT, INPUT_REQUIRED),
    )
)

ENVELOPE_BODY: Final[dict[str, Any]] = {
    "required": True,
    "content": {
        "application/json": {
            "schema": JsonRpcRequest.model_json_schema(),
            "examples": REQUEST_EXAMPLES,
        }
    },
}

TURN_RESPONSE: Final[dict[str, Any]] = {
    "model": JsonRpcFailure,
    "description": (
        "A stream of task events, or a JSON-RPC error object for a refused "
        "call — including a renderer whose capabilities do not list the "
        "finance catalog. Order: `status-update(working)` → one "
        "`artifact-update` per surface (an A2UI `DataPart` holding one "
        "`createSurface`) or per function answer → `message` (the answer and "
        "the chips, no `renderIntents`) → a terminal `status-update`."
    ),
    "content": {
        EVENT_STREAM: {"schema": {"type": "string"}, "example": STREAM_EXAMPLE},
        "application/json": {
            "example": {
                "jsonrpc": "2.0",
                "id": "req-1",
                "error": {"code": -32602, "message": "Invalid parameters"},
            }
        },
    },
}

CATALOG_RESPONSE: Final[dict[str, Any]] = {
    "description": "The generated A2UI v1.0 catalog, as a JSON Schema document.",
    "content": {
        "application/json": {
            "schema": {"type": "object"},
            "example": {
                "$id": CATALOG_ID,
                "catalogId": CATALOG_ID,
                "protocolVersion": PROTOCOL_VERSION,
                "components": {"PortfolioSummary": {"allowedParents": ["Surface"]}},
                "functions": {"renderView": {"returnType": "object"}},
            },
        }
    },
}

__all__ = [
    "CATALOG_RESPONSE",
    "ENVELOPE_BODY",
    "EVENT_STREAM",
    "REQUEST_EXAMPLES",
    "STREAM_EXAMPLE",
    "TURN_RESPONSE",
]
