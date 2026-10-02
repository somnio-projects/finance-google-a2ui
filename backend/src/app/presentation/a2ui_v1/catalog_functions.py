"""The ``functions`` map of the v1.0 catalog: one function, ``renderView`` (D-6).

An edit on a surface — a different range, another lot method — is not a turn
and never reaches the model. The renderer calls ``renderView``; because it is
``rendererOnly`` and the renderer registers no local implementation, the call
is routed to the agent, which validates the options against the projection's
own model and renders deterministically (ADR-M D-6, ADR-K D-3).

The ``options`` schema is an open object on purpose: each projection's options
model carries its own ``$defs``, which a v1.0 catalog may not, and inlining
twelve of them would publish a second copy of bounds the agent already
enforces. The bound that matters is server-side; the catalog names the views.
"""

from collections.abc import Sequence
from typing import Any, Final

from app.presentation.a2ui_v1.wire import COMPONENT_ID_PATTERN, RENDER_VIEW
from app.presentation.registry import Projection

_PURPOSE: Final[str] = (
    "Re-render one component of this surface with new declared options. The "
    "agent validates `options` against the view's own options model and "
    "answers `{componentId, view}`, then an `updateDataModel` at "
    "`/<componentId>`; it never asks the model. An undeclared or out-of-range "
    "option answers `INVALID_FUNCTION_CALL`."
)


def render_view(projections: Sequence[Projection]) -> dict[str, Any]:
    """Return the ``renderView`` function definition.

    Args:
        projections: The registry's contents, ordered by id.

    Returns:
        The definition: a wire-level ``FunctionCall`` schema plus its
        ``returnType`` and ``allowedCallers`` metadata.
    """
    return {
        "type": "object",
        "description": _PURPOSE,
        "returnType": "object",
        "allowedCallers": "rendererOnly",
        "properties": {
            "call": {"const": RENDER_VIEW},
            "args": {
                "type": "object",
                "properties": {
                    "componentId": {
                        "type": "string",
                        "pattern": COMPONENT_ID_PATTERN,
                        "description": "The component to re-render; its data path.",
                    },
                    "view": {
                        "type": "string",
                        "enum": [projection.id for projection in projections],
                        "description": "The registered projection to render.",
                    },
                    "options": {
                        "type": "object",
                        "description": "The view's declared options, and only those.",
                    },
                },
                "required": ["componentId", "view", "options"],
                "additionalProperties": False,
            },
        },
        "required": ["call", "args"],
    }


def functions(projections: Sequence[Projection]) -> dict[str, dict[str, Any]]:
    """Return the catalog's ``functions`` map."""
    return {RENDER_VIEW: render_view(projections)}


def any_function() -> dict[str, Any]:
    """Return ``$defs.anyFunction``: one ``$ref`` per declared function."""
    return {"oneOf": [{"$ref": f"#/functions/{RENDER_VIEW}"}]}


__all__ = ["any_function", "functions", "render_view"]
