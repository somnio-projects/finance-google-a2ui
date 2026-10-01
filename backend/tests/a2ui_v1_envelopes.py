"""JSON-RPC bodies a v1.0 renderer sends, shared by every v1.0 suite.

The data-part bodies are read from ``docs/a2ui/v1.0/examples/`` rather than
rebuilt, so the suites send exactly what ``frontend_v1/`` will send.
"""

import copy
from typing import Any

from app.presentation.a2ui_v1.wire import CATALOG_ID
from tests.a2ui_v1_schemas import EXAMPLES, load

CAPABLE: dict[str, Any] = {
    "a2uiRendererCapabilities": {"v1.0": {"supportedCatalogIds": [CATALOG_ID]}}
}


def envelope(
    part: dict[str, Any], *, metadata: dict[str, Any] | None = None
) -> dict[str, Any]:
    """Wrap one part in a ``message/stream`` call that declares the catalog."""
    return {
        "jsonrpc": "2.0",
        "id": "req-1",
        "method": "message/stream",
        "params": {
            "message": {
                "role": "user",
                "parts": [part],
                "contextId": "ctx-1",
                "metadata": CAPABLE if metadata is None else metadata,
            }
        },
    }


def prose(text: str, **kwargs: Any) -> dict[str, Any]:
    """A typed question."""
    return envelope({"kind": "text", "text": text}, **kwargs)


def example(name: str) -> dict[str, Any]:
    """A fresh copy of one example data part, safe to mutate."""
    return copy.deepcopy(load(EXAMPLES / name))


def render_view(**args: Any) -> dict[str, Any]:
    """The example ``callAgentFunction``, with its arguments overridden."""
    part = example("call_agent_function.render_view.json")
    part["data"][0]["callAgentFunction"]["callFunction"]["args"].update(args)
    return envelope(part)


def drill(**context: Any) -> dict[str, Any]:
    """The example ``drill_attribution`` action, with its context overridden."""
    part = example("action.drill_attribution.json")
    part["data"][0]["action"]["context"].update(context)
    return envelope(part)


__all__ = ["CAPABLE", "drill", "envelope", "example", "prose", "render_view"]
