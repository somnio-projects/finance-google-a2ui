"""The catalog as prompt text, generated from the registry (ADR-K D-14).

GGU-14 feeds this to the model. It is **generated, never hand-copied**: a
hand-written list teaches the model views that no longer exist and hides the
ones that do, and a model taught a stale catalog invents payloads — exactly
what ADR-K D-12 forbids. Option bounds come from each options model's own JSON
schema, so widening a bound updates the prompt in the same commit.
"""

from collections.abc import Mapping, Sequence
from typing import Any, Final

from app.presentation.option_text import (
    NO_OPTIONS,
    Defs,
    option_bounds,
)
from app.presentation.registry import Projection

PROMPT_HEADER: Final[str] = (
    "Available views. Pick one by id and fill only the options listed for it; "
    "an unknown view, an undeclared option or an out-of-range value is "
    "rejected and the default view is rendered instead. Never invent a payload "
    "shape, a field or a formatted number."
)


def _options_line(projection: Projection) -> str:
    """Return the option summary of one projection, from its JSON schema."""
    schema = projection.options.model_json_schema()
    properties: Mapping[str, Any] = schema.get("properties", {})
    defs: Defs = schema.get("$defs")
    described = ", ".join(
        f"{name} ({option_bounds(spec, defs)})" for name, spec in properties.items()
    )
    return f"  options: {described or NO_OPTIONS}"


def _guidance_lines(projection: Projection) -> list[str]:
    """Return the do/don't pair for ``projection``, or nothing.

    A projection whose design page has not been written contributes no lines
    at all rather than an empty "use when:" — a blank instruction is worse
    than a missing one, because the model reads it as a constraint it cannot
    satisfy (``presentation.guidance``).
    """
    guidance = projection.guidance
    if guidance is None:
        return []
    return [
        f"  use when: {guidance.use_when}",
        f"  do not use for: {guidance.avoid_when}",
    ]


def prompt_fragment(projections: Sequence[Projection]) -> str:
    """Render the registry as the catalog text the model is taught.

    Args:
        projections: Every registered projection.

    Returns:
        The header, then per projection: id with its purpose, its declared
        options with their bounds, and — where design has written one — the
        do/don't pair that says when to reach for it (GGU-53, spec 0023).
    """
    lines = [PROMPT_HEADER]
    for projection in projections:
        lines.append(f"- {projection.id} — {projection.summary}")
        lines.append(_options_line(projection))
        lines.extend(_guidance_lines(projection))
    return "\n".join(lines)


__all__ = ["PROMPT_HEADER", "prompt_fragment"]
