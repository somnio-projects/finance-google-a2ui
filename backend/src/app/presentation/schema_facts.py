"""What one JSON-schema node says about itself (GGU-41).

Every classification the frozen contract prints is decided here, and every one
of them is **structural**: a node is a figure because its declared type is
numeric, a string is pre-formatted because it sits beside a figure, a field can
be absent because the schema says so. No rule keys on a field name — the one
that does (an editable field matches a declared option) lives in
``inventory`` and is documented in the generated document as doing so.

Keeping the rules here rather than inside the walk is what lets each of them be
tested against a hand-written schema fragment, one shape per case.
"""

from collections.abc import Mapping
from json import dumps
from typing import Any, Final

NULL_TYPE: Final[Mapping[str, Any]] = {"type": "null"}
NUMERIC_TYPES: Final[frozenset[str]] = frozenset({"integer", "number"})
CONTAINER_TYPES: Final[frozenset[str]] = frozenset({"object", "array"})
NONE: Final[str] = "—"


def variant_types(spec: Mapping[str, Any]) -> set[str]:
    """Return the declared types of a union node, empty when it is not one.

    Args:
        spec: A JSON-schema node.

    Returns:
        The ``type`` of every non-null member of its ``anyOf``.
    """
    return {
        variant.get("type", "object")
        for variant in spec.get("anyOf", ())
        if variant != NULL_TYPE
    }


def collapse(spec: Mapping[str, Any]) -> Mapping[str, Any]:
    """Drop a lone ``null`` member so an optional field shows its real type.

    Args:
        spec: A JSON-schema node, possibly ``anyOf[X, null]``.

    Returns:
        ``X`` with the node's own keys kept, or ``spec`` unchanged when the
        union carries more than one real member (a ``Decimal``, say).
    """
    members = [item for item in spec.get("anyOf", ()) if item != NULL_TYPE]
    if len(members) == 1:
        return {**members[0], **{k: v for k, v in spec.items() if k != "anyOf"}}
    return spec


def is_numeric(spec: Mapping[str, Any]) -> bool:
    """Say whether ``spec`` carries a figure rather than a string."""
    return bool((variant_types(spec) or {spec.get("type")}) & NUMERIC_TYPES)


def bound(spec: Mapping[str, Any]) -> str:
    """Return the declared bound of ``spec``, or an empty string when free."""
    if "maxLength" in spec:
        return f"≤{spec['maxLength']} chars"
    if "maxItems" in spec:
        return f"≤{spec['maxItems']} items"
    if "minimum" in spec or "maximum" in spec:
        return f"{spec.get('minimum')}..{spec.get('maximum')}"
    return ""


def describe(spec: Mapping[str, Any]) -> str:
    """Return the type and the declared bound of one node, in one cell."""
    if "const" in spec:
        return f"const {spec['const']!r}"
    if "enum" in spec:
        return "enum " + " / ".join(str(value) for value in spec["enum"])
    types = variant_types(spec)
    if types == {"number", "string"}:
        return "decimal"
    if types:
        return " / ".join(sorted(types))
    declared = str(spec.get("type", "object"))
    limit = bound(spec)
    return f"{declared} {limit}" if limit else declared


def presence(spec: Mapping[str, Any], *, required: bool) -> str:
    """Say whether the payload always carries this field, and with what."""
    if required:
        return "required"
    if "default" in spec:
        return f"default `{dumps(spec['default'])}`"
    return "optional"


def binding(spec: Mapping[str, Any], *, paired: bool) -> str:
    """Say how the client uses the value — the `*Display` rule lives here.

    Args:
        spec: The resolved schema node of one leaf or container.
        paired: Whether the object holding it also declares a figure, which is
            what makes a string the pre-formatted half of an ADR-E pair.

    Returns:
        One of ``constant``, ``enum``, ``container``, ``raw``, ``flag``,
        ``display`` or ``text``.
    """
    if "const" in spec:
        return "constant"
    if "enum" in spec:
        return "enum"
    if "properties" in spec or spec.get("type") in CONTAINER_TYPES:
        return "container"
    if is_numeric(spec):
        return "raw"
    if spec.get("type") == "boolean":
        return "flag"
    return "display" if paired else "text"


def state(spec: Mapping[str, Any], *, nullable: bool) -> str:
    """Name the UI state this field can drive, or ``—`` when it drives none."""
    if spec.get("type") == "array":
        return "empty"
    if nullable:
        return "null"
    if "enum" in spec or spec.get("type") == "boolean":
        return "variant"
    return NONE


__all__ = [
    "CONTAINER_TYPES",
    "NONE",
    "NULL_TYPE",
    "NUMERIC_TYPES",
    "binding",
    "bound",
    "collapse",
    "describe",
    "is_numeric",
    "presence",
    "state",
    "variant_types",
]
