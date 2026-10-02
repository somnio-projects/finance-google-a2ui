"""Why ``renderView`` refused a set of options, in one sentence (ADR-M D-6).

The judge is the projection's own options model — the same one ``?view=`` and
a render intent are held to (ADR-K D-3) — so nothing here decides validity.
It only turns pydantic's verdict into the sentence a renderer can show:

* an option with a closed set of values names the set, which is the
  projection's declaration and never the caller's input;
* an undeclared option names the option (a bounded identifier) and the view;
* anything else says the value is out of range, without repeating it.

The value the caller sent is never echoed — the rule ``presentation.resolve``
records, for the same reason.
"""

from collections.abc import Mapping
from typing import Any, Final

from pydantic import ValidationError

from app.presentation.option_text import DEFS_PREFIX
from app.presentation.registry import Projection

UNDECLARED: Final[str] = "extra_forbidden"


def _choices(spec: Mapping[str, Any], defs: Mapping[str, Any]) -> list[str]:
    """Return the closed set of values ``spec`` declares, or nothing."""
    for candidate in (spec, *spec.get("anyOf", ())):
        ref = str(candidate.get("$ref", ""))
        resolved = (
            defs.get(ref.removeprefix(DEFS_PREFIX), candidate) if ref else candidate
        )
        if "enum" in resolved:
            return [str(value) for value in resolved["enum"]]
    return []


def options_rejection(projection: Projection, options: Mapping[str, Any]) -> str | None:
    """Judge ``options`` against ``projection`` and explain a refusal.

    Args:
        projection: The registered view the renderer asked for.
        options: The options it sent, unvalidated.

    Returns:
        ``None`` when the projection accepts them, otherwise one sentence
        naming the first offending option.
    """
    try:
        projection.options.model_validate(dict(options))
    except ValidationError as exc:
        return _sentence(projection, exc)
    return None


def _sentence(projection: Projection, exc: ValidationError) -> str:
    """Describe the first error pydantic reported."""
    first = exc.errors()[0]
    name = ".".join(str(part) for part in first["loc"])
    if not name:
        # A rule across options (a model validator) names no single field.
        return f"These options do not fit together for view '{projection.id}'."
    if first["type"] == UNDECLARED:
        return f"Option '{name}' is not declared by view '{projection.id}'."
    schema = projection.options.model_json_schema()
    spec = schema.get("properties", {}).get(name, {})
    choices = _choices(spec, schema.get("$defs", {}))
    if choices:
        return f"Option '{name}' must be one of: {', '.join(choices)}."
    return f"Option '{name}' is out of range for view '{projection.id}'."


__all__ = ["UNDECLARED", "options_rejection"]
