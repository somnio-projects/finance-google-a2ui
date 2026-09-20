"""The catalog as prompt text, generated from the registry (ADR-K D-14).

GGU-14 feeds this to the model. It is **generated, never hand-copied**: a
hand-written list teaches the model views that no longer exist and hides the
ones that do, and a model taught a stale catalog invents payloads — exactly
what ADR-K D-12 forbids. Option bounds come from each options model's own JSON
schema, so widening a bound updates the prompt in the same commit.
"""

from collections.abc import Mapping, Sequence
from typing import Any, Final

from app.presentation.registry import Projection

PROMPT_HEADER: Final[str] = (
    "Available views. Pick one by id and fill only the options listed for it; "
    "an unknown view, an undeclared option or an out-of-range value is "
    "rejected and the default view is rendered instead. Never invent a payload "
    "shape, a field or a formatted number."
)
NO_OPTIONS: Final[str] = "none"


def option_bounds(spec: Mapping[str, Any]) -> str:
    """Return a one-line description of the values one option accepts.

    Args:
        spec: The option's JSON-schema fragment.

    Returns:
        Wording the model can act on, such as ``integer 1..20``.
    """
    if "const" in spec:
        return f"only {spec['const']!r}"
    if "enum" in spec:
        return "one of " + ", ".join(repr(value) for value in spec["enum"])
    if spec.get("type") == "integer":
        return f"integer {spec.get('minimum')}..{spec.get('maximum')}"
    if spec.get("type") == "boolean":
        return "true or false"
    if spec.get("type") == "string":
        return f"string matching {spec['pattern']}"
    return "list of names"


def _options_line(projection: Projection) -> str:
    """Return the option summary of one projection, from its JSON schema."""
    properties: Mapping[str, Any] = projection.options.model_json_schema().get(
        "properties", {}
    )
    described = ", ".join(
        f"{name} ({option_bounds(spec)})" for name, spec in properties.items()
    )
    return f"  options: {described or NO_OPTIONS}"


def prompt_fragment(projections: Sequence[Projection]) -> str:
    """Render the registry as the catalog text the model is taught.

    Args:
        projections: Every registered projection.

    Returns:
        One header line, then two lines per projection: id with its purpose,
        and its declared options with their bounds.
    """
    lines = [PROMPT_HEADER]
    for projection in projections:
        lines.append(f"- {projection.id} — {projection.summary}")
        lines.append(_options_line(projection))
    return "\n".join(lines)


__all__ = ["NO_OPTIONS", "PROMPT_HEADER", "option_bounds", "prompt_fragment"]
