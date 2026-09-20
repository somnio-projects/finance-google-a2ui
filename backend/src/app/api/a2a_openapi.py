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
    '"options":{"window":"30d"}}]}\n'
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

__all__ = ["REQUEST_EXAMPLE", "RPC_ERROR_EXAMPLE", "STREAM_EXAMPLE"]
