"""How one declared option is described to the model, from its JSON schema.

Split out of ``prompt.py`` because it is a different job: that module decides
**what the catalog text says**, this decides **how a single bound reads**. It
grew when the fall-through turned out to be a lie — a nullable ticker reached
the model as ``list of names``, and two charts changed their own design to
route around the wording instead of sending it (spec 0016 OD-9).

The rule here: describe what the schema says, and when the shape is not
recognised, say so. A guessed bound is worse than an absent one, because the
model acts on it.
"""

from collections.abc import Callable, Mapping, Sequence
from typing import Any, Final

NO_OPTIONS: Final[str] = "none"
#: What an option whose schema this renderer does not recognise is called.
#: Naming the gap beats inventing a bound the model will then try to satisfy.
UNKNOWN: Final[str] = "an unrecognised shape — do not guess"
#: Where pydantic puts a named sub-schema (an enum, a nested model).
DEFS_PREFIX: Final[str] = "#/$defs/"

#: A schema's ``$defs`` block, threaded through so a ``$ref`` can be followed.
Defs = Mapping[str, Mapping[str, Any]] | None


def option_bounds(spec: Mapping[str, Any], defs: Defs = None) -> str:
    """Return a one-line description of the values one option accepts.

    This text is the model's only account of what an option will accept, so a
    wrong description is worse than a missing one: it teaches the model to
    send something that will be rejected. Every branch below therefore
    describes what the schema actually says, and an unrecognised shape says
    so rather than guessing.

    Args:
        spec: The option's JSON-schema fragment.
        defs: The schema's ``$defs``, so a ``$ref`` resolves to real bounds
            instead of being described as unrecognised.

    Returns:
        Wording the model can act on, such as ``integer 1..20``.
    """
    if "const" in spec:
        return f"only {spec['const']!r}"
    if "enum" in spec:
        return "one of " + ", ".join(repr(value) for value in spec["enum"])
    if "anyOf" in spec:
        # A nullable option: pydantic emits ``str | None`` as a two-branch
        # ``anyOf`` with no top-level ``type``. Describing the real branch and
        # naming the null one is the difference between the model learning
        # "a ticker, or omit it" and learning "list of names" (spec 0016 OD-9).
        return _any_of_bounds(spec["anyOf"], defs)
    return _typed_bounds(spec, defs)


def _any_of_bounds(branches: Sequence[Mapping[str, Any]], defs: Defs) -> str:
    """Describe the non-null branches of a nullable option."""
    described = [_typed_bounds(b, defs) for b in branches if b.get("type") != "null"]
    nullable = any(b.get("type") == "null" for b in branches)
    text = " or ".join(dict.fromkeys(described)) if described else UNKNOWN
    return f"{text}, or omit it" if nullable else text


def _resolve(spec: Mapping[str, Any], defs: Defs) -> Mapping[str, Any]:
    """Follow a local ``$ref`` into ``$defs``; return ``spec`` unchanged if not one."""
    ref = spec.get("$ref")
    if not isinstance(ref, str) or not ref.startswith(DEFS_PREFIX):
        return spec
    return (defs or {}).get(ref.removeprefix(DEFS_PREFIX), spec)


def _number_bounds(spec: Mapping[str, Any], _defs: Defs) -> str:
    """Describe a float bound, preferring the exclusive minimum when present."""
    low = spec.get("exclusiveMinimum", spec.get("minimum"))
    return f"number {low}..{spec.get('maximum')}"


def _integer_bounds(spec: Mapping[str, Any], _defs: Defs) -> str:
    """Describe an integer bound."""
    return f"integer {spec.get('minimum')}..{spec.get('maximum')}"


def _boolean_bounds(_spec: Mapping[str, Any], _defs: Defs) -> str:
    """Describe a boolean."""
    return "true or false"


def _string_bounds(spec: Mapping[str, Any], _defs: Defs) -> str:
    """Describe a string by its pattern, else its length, else plainly."""
    pattern = spec.get("pattern")
    if pattern:
        return f"string matching {pattern}"
    limit = spec.get("maxLength")
    return f"string of up to {limit} characters" if limit else "text"


#: One describer per JSON-schema type. A table rather than a chain: the next
#: type is a row, and nothing else has to be re-read to add it.
DESCRIBERS: Final[dict[str, Callable[[Mapping[str, Any], Defs], str]]] = {
    "number": _number_bounds,
    "integer": _integer_bounds,
    "boolean": _boolean_bounds,
    "string": _string_bounds,
}


def _typed_bounds(spec: Mapping[str, Any], defs: Defs) -> str:
    """Describe one concrete JSON-schema type, following a ``$ref`` first."""
    spec = _resolve(spec, defs)
    if "enum" in spec:
        return "one of " + ", ".join(repr(value) for value in spec["enum"])
    if "const" in spec:
        return f"only {spec['const']!r}"
    kind = spec.get("type")
    if kind == "array":
        return _array_bounds(spec, defs)
    describe = DESCRIBERS.get(str(kind))
    return describe(spec, defs) if describe else UNKNOWN


def _array_bounds(spec: Mapping[str, Any], defs: Defs) -> str:
    """Describe a list by its cap and its element type, naming only what is there."""
    cap = spec.get("maxItems")
    sized = f"list of up to {cap}" if cap is not None else "list"
    item = spec.get("items")
    if not isinstance(item, dict):
        return sized
    return f"{sized} ({_typed_bounds(item, defs)})"


__all__ = ["DEFS_PREFIX", "NO_OPTIONS", "UNKNOWN", "Defs", "option_bounds"]
