"""The designer-facing field inventory of a payload schema (GGU-41).

GGU-41 asks for a frozen, versioned inventory of every field a component
receives. It is derived from the projection's own JSON schema, so the inventory
**is** the schema rather than a transcription of it — and a transcription is
the source that goes stale.

The walk is the only place a field name is consulted: a payload field named
after a declared option is editable, because under ADR-K D-3 a declared option
is the only thing a caller may send back. Every other rule is structural and
lives in ``schema_facts``.
"""

from collections.abc import Iterator, Mapping
from dataclasses import dataclass
from typing import Any, Final

from app.presentation.schema_facts import (
    NONE,
    NULL_TYPE,
    binding,
    collapse,
    describe,
    is_pair,
    presence,
    state,
)

#: How deep the walk follows nested objects before it stops — a self-referencing
#: model would otherwise recurse forever, and six levels is deeper than any
#: payload a widget can sensibly bind.
MAX_DEPTH: Final[int] = 6


@dataclass(frozen=True, slots=True)
class InventoryField:
    """One row of a component's frozen field inventory."""

    path: str
    kind: str
    presence: str
    binding: str
    state: str
    interaction: str


@dataclass(frozen=True, slots=True)
class _Context:
    """What the rows of one object need to know about their surroundings."""

    inputs: Mapping[str, str]
    paired: bool


def _resolve(spec: Mapping[str, Any], defs: Mapping[str, Any]) -> Mapping[str, Any]:
    """Inline a ``$ref`` and collapse an ``anyOf`` that only adds ``null``."""
    ref = spec.get("$ref")
    if ref is not None:
        target: Mapping[str, Any] = defs[ref.rsplit("/", 1)[-1]]
        spec = {**target, **{k: v for k, v in spec.items() if k != "$ref"}}
    return collapse(spec)


def _row(
    name: str,
    spec: Mapping[str, Any],
    *,
    prefix: str,
    required: bool,
    nullable: bool,
    context: _Context,
) -> InventoryField:
    """Classify one property into the row the contract document prints."""
    return InventoryField(
        path=f"{prefix}{name}",
        kind=describe(spec),
        presence=presence(spec, required=required),
        binding=binding(spec, paired=context.paired),
        state=state(spec, nullable=nullable),
        interaction=context.inputs.get(name, NONE),
    )


def _children(
    name: str,
    spec: Mapping[str, Any],
    defs: Mapping[str, Any],
    *,
    prefix: str,
    inputs: Mapping[str, str],
    depth: int,
) -> Iterator[InventoryField]:
    """Walk into a container property, stopping at ``MAX_DEPTH``."""
    items = spec.get("items")
    if depth >= MAX_DEPTH or (items is None and "properties" not in spec):
        return
    child = _resolve(items, defs) if items is not None else spec
    step = "[]." if items is not None else "."
    yield from _object(
        child, defs, prefix=f"{prefix}{name}{step}", inputs=inputs, depth=depth + 1
    )


def _object(
    spec: Mapping[str, Any],
    defs: Mapping[str, Any],
    *,
    prefix: str,
    inputs: Mapping[str, str],
    depth: int,
) -> Iterator[InventoryField]:
    """Yield a row per property of one object, then recurse into each."""
    properties: Mapping[str, Any] = spec.get("properties", {})
    required = set(spec.get("required", ()))
    resolved = {name: _resolve(sub, defs) for name, sub in properties.items()}
    context = _Context(inputs=inputs, paired=is_pair(resolved))
    for name, sub in resolved.items():
        yield _row(
            name,
            sub,
            prefix=prefix,
            required=name in required,
            nullable=NULL_TYPE in properties[name].get("anyOf", ()),
            context=context,
        )
        yield from _children(name, sub, defs, prefix=prefix, inputs=inputs, depth=depth)


def inventory(
    schema: Mapping[str, Any], *, inputs: Mapping[str, str]
) -> tuple[InventoryField, ...]:
    """Flatten a payload schema into one row per bindable field.

    Args:
        schema: The projection DTO's JSON schema, ``$defs`` and all.
        inputs: Declared option name → the bounds cell to print, so a field
            that round-trips through an option is marked editable.

    Returns:
        Every field, parents before children, in declaration order.
    """
    defs = schema.get("$defs", {})
    return tuple(_object(schema, defs, prefix="", inputs=inputs, depth=0))


__all__ = ["MAX_DEPTH", "InventoryField", "inventory"]
