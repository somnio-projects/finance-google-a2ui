"""Translate a tool's JSON Schema into the subset Gemini parses (GGU-81).

The subset itself — which keywords the API accepts and which it refuses, and
how that was measured — is ``tool_schema_keys.py``. This module applies it.

The translation belongs here, at the wire boundary, and nowhere else. A tool
goes on publishing bounded, documented, exemplified arguments — that is what
``tests/unit/agent/test_tool_argument_bounds.py`` gates, and what the OpenAPI
document needs — and this module decides what survives the crossing.

Two refused keywords are **translated instead of dropped**, because dropping
them would silently discard a bound the model is entitled to see — precisely
the advertised-but-unenforced failure that bounds gate exists to catch:

* ``$ref``/``$defs`` are resolved into the schema that referenced them;
* ``const`` becomes a single-valued ``enum``.
"""

from collections.abc import Mapping
from typing import Any

from app.core.errors import ConfigurationError
from app.infra.model.tool_schema_keys import (
    BRANCH_LISTS,
    BRANCH_NODES,
    SUPPORTED_KEYS,
)


def _child(key: str, value: Any, defs: Mapping[str, Any], seen: frozenset[str]) -> Any:
    """Sanitise the value of one schema key, recursing into sub-schemas.

    Args:
        key: The key the value belongs to.
        value: Its raw value, straight from the generated JSON Schema.
        defs: The document's ``$defs``, for resolving references below.
        seen: Definitions already being expanded on this path.

    Returns:
        The value to put on the wire.
    """
    if key in BRANCH_LISTS:
        return [_schema(branch, defs, seen) for branch in value]
    if key in BRANCH_NODES:
        return _schema(value, defs, seen)
    if key == "properties":
        return {name: _schema(prop, defs, seen) for name, prop in value.items()}
    return value


def _dereference(
    ref: str, node: Mapping[str, Any], defs: Mapping[str, Any], seen: frozenset[str]
) -> dict[str, Any]:
    """Expand ``$ref`` in place, keeping the keys that sat beside it.

    A reference is resolved rather than dropped: an unresolved ``$ref`` leaves
    a field with no type and no bound, which is how an enum or a nested model
    would quietly become "anything at all" in the model's eyes.

    Args:
        ref: The reference, ``#/$defs/<name>``.
        node: The schema carrying it; its own keys win over the target's.
        defs: The document's definitions.
        seen: Definitions already being expanded on this path.

    Returns:
        The referenced schema, sanitised.

    Raises:
        ConfigurationError: When the definition is missing, or the definitions
            are cyclic and so cannot be written out at all. A tool whose
            arguments cannot go on the wire is a bug in the tool, and naming
            it here beats a 400 for the whole turn.
    """
    name = ref.rpartition("/")[2]
    if name in seen:
        msg = f"tool schema reference {ref!r} is cyclic"
        raise ConfigurationError(msg)
    target = defs.get(name)
    if target is None:
        msg = f"tool schema reference {ref!r} resolves to nothing"
        raise ConfigurationError(msg)
    siblings = {key: value for key, value in node.items() if key != "$ref"}
    return _schema({**target, **siblings}, defs, seen | {name})


def _schema(
    node: Mapping[str, Any], defs: Mapping[str, Any], seen: frozenset[str]
) -> dict[str, Any]:
    """Return ``node`` as the subset Gemini accepts.

    Args:
        node: One JSON Schema node.
        defs: The document's ``$defs``.
        seen: Definitions already being expanded on this path.

    Returns:
        A new node carrying only supported keys, with references resolved.
    """
    ref = node.get("$ref")
    if isinstance(ref, str):
        return _dereference(ref, node, defs, seen)
    kept: dict[str, Any] = {}
    if "const" in node and "enum" not in node:
        kept["enum"] = [node["const"]]
    for key, value in node.items():
        if key in SUPPORTED_KEYS:
            kept[key] = _child(key, value, defs, seen)
    return kept


def to_gemini_schema(parameters: Mapping[str, Any]) -> dict[str, Any]:
    """Translate a tool's JSON Schema into Gemini's ``parameters``.

    Args:
        parameters: The schema the tool publishes, as pydantic generated it.

    Returns:
        The same arguments expressed in the subset ``generateContent`` parses.

    Raises:
        ConfigurationError: When a ``$ref`` cannot be resolved.
    """
    return _schema(parameters, parameters.get("$defs", {}), frozenset())


__all__ = ["to_gemini_schema"]
