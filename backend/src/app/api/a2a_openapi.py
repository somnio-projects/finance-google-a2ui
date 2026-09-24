"""What the A2A surface looks like on the wire, for the OpenAPI document.

Split from ``a2a.py`` under the 150-line budget, the same way
``view_renders_openapi`` was — and for a second reason: these values must stay
recognisably identical to what ``app.services.a2a_events`` builds, so keeping
them in one small file makes that comparison a glance rather than a hunt.

This endpoint is the one the client is actually written against. It is
JSON-RPC, its body is one envelope for many methods, and its answer is either
an event stream or an error object, so FastAPI can derive **no** schema from
the signature. Everything a client author knows about this route, they know
from the examples below. They were transcribed from the builders in
``a2a_events`` rather than imagined; `test_a2a_examples_match_the_events_module`
fails if the two drift.
"""

from typing import Any, Final

from app.schemas.a2a import JsonRpcFailure, JsonRpcRequest

#: The media type a turn streams back. Here rather than in `a2a.py` because
#: both the route's handler and the response shape below need it.
EVENT_STREAM: Final[str] = "text/event-stream"

#: A `message/stream` call — the only method the surface implements today.
REQUEST_EXAMPLE: Final[dict[str, Any]] = {
    "jsonrpc": "2.0",
    "id": "req-1",
    "method": "message/stream",
    "params": {
        "message": {
            "role": "user",
            "parts": [{"kind": "text", "text": "How did my portfolio do this month?"}],
            "contextId": "c2f1b8a4-3d5e-4a7b-9c11-8e2f6d0a1b33",
        }
    },
}

#: One turn as it arrives, in order. `status-update(working)` opens it, a
#: `render-intent` lands per surface *while the turn is still running*
#: (ADR-K D-19), the terminal `message` repeats every surface in
#: `renderIntents`, and a final `status-update` closes it with `final: true`.
STREAM_EXAMPLE: Final[str] = (
    'data: {"kind":"status-update","taskId":"7b1e...","contextId":"c2f1...",'
    '"status":{"state":"working"},"final":false}\n'
    "\n"
    'data: {"kind":"render-intent","taskId":"7b1e...","contextId":"c2f1...",'
    '"index":0,"renderIntent":{"view":"attribution.waterfall.v1",'
    '"options":{"window":"30d"}}}\n'
    "\n"
    'data: {"kind":"message","taskId":"7b1e...","contextId":"c2f1...",'
    '"role":"agent","parts":[{"kind":"text","text":"Your portfolio is up '
    '2.4% this month, driven by NVDA."}],'
    '"renderIntents":[{"view":"attribution.waterfall.v1",'
    '"options":{"window":"30d"}}],'
    '"suggestions":[{"key":"biggest-drivers","label":"Biggest drivers"}]}\n'
    "\n"
    'data: {"kind":"status-update","taskId":"7b1e...","contextId":"c2f1...",'
    '"status":{"state":"completed"},"final":true}\n'
    "\n"
)

#: A refusal. Note the status code: this is **HTTP 200** with a JSON-RPC error
#: object, not a 4xx — the one place in this service where a failure is not an
#: RFC 9457 problem document (ADR-J D-3). A client of both surfaces parses two
#: error shapes, and this example is where it learns that.
RPC_ERROR_EXAMPLE: Final[dict[str, Any]] = {
    "jsonrpc": "2.0",
    "id": "req-1",
    "error": {"code": -32601, "message": "Method not found"},
}

#: The body, spelled out because FastAPI derives nothing from a raw ``Request``.
#: The schema is the envelope model's own, inline rather than a `$ref`: no
#: route declares the model as a parameter, so nothing would put it in
#: ``components``. An example with no schema beside it is a body a generated
#: client cannot type (spec 0038 OD-5).
ENVELOPE_BODY: Final[dict[str, Any]] = {
    "required": True,
    "content": {
        "application/json": {
            "schema": JsonRpcRequest.model_json_schema(),
            "example": REQUEST_EXAMPLE,
        }
    },
}

#: The 200, which is two media types and no response model: an event stream
#: for `message/stream`, or a JSON-RPC error object for anything refused.
#: ``model`` is what puts `JsonRpcFailure` — and the error object it carries —
#: into ``components.schemas``; the content map then names what is really
#: answered. The stream itself is text, not JSON, so its schema is a string.
TURN_RESPONSE: Final[dict[str, Any]] = {
    "model": JsonRpcFailure,
    "content": {
        EVENT_STREAM: {
            "schema": {
                "type": "string",
                "description": (
                    "Server-sent events: one `data:` line per event, separated "
                    "by a blank line. Each payload is one JSON object of the "
                    "kinds in the example."
                ),
            },
            "example": STREAM_EXAMPLE,
        },
        "application/json": {"example": RPC_ERROR_EXAMPLE},
    },
    "description": (
        "A stream of task events for `message/stream`, or a JSON-RPC error "
        "object for an unknown or unsupported method. The event order is "
        "`status-update(working)` → one `render-intent` per surface, as each "
        "becomes ready → `message` carrying the answer and the full "
        "`renderIntents` list → a terminal `status-update`. A client may "
        "render each `render-intent` immediately, or ignore them and use the "
        "terminal message: both carry the same surfaces."
    ),
}

__all__ = [
    "ENVELOPE_BODY",
    "EVENT_STREAM",
    "REQUEST_EXAMPLE",
    "RPC_ERROR_EXAMPLE",
    "STREAM_EXAMPLE",
    "TURN_RESPONSE",
]
