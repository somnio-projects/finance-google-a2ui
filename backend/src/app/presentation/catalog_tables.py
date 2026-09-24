"""The tables of the frozen contract, rendered as Markdown (GGU-41).

Markdown because the contract has to diff in a pull request and render on
GitHub with no tooling — the same reason the architecture diagrams are Mermaid
in Markdown rather than exported images.

Both tables are built from a schema, never from a literal: the options table
from the projection's options model, the inventory from its payload model. The
bounds column reuses ``prompt.option_bounds``, so the sentence a designer reads
about an option and the sentence the model is taught about it are the same
sentence.
"""

from collections.abc import Iterable, Mapping, Sequence
from json import dumps
from typing import Any, Final

from app.presentation.inventory import InventoryField
from app.presentation.option_text import option_bounds
from app.presentation.schema_facts import NONE, collapse, describe

OPTION_HEADER: Final[tuple[str, ...]] = (
    "Option",
    "Type / format",
    "Accepts",
    "Default",
    "Description",
)
FIELD_HEADER: Final[tuple[str, ...]] = (
    "Field",
    "Type / format",
    "Presence",
    "Binding",
    "State",
    "Input",
)
INDEX_HEADER: Final[tuple[str, ...]] = (
    "Frozen id",
    "Component",
    "Digest",
    "Fields",
    "Inputs",
    "Purpose",
)
NO_OPTIONS: Final[str] = "_This projection declares no options._"
READ_ONLY: Final[str] = "read-only"


def cell(value: str) -> str:
    """Return ``value`` safe to drop into a Markdown table cell."""
    return value.replace("|", "\\|").replace("\n", " ").strip()


def table(header: Sequence[str], rows: Iterable[Sequence[str]]) -> str:
    """Render one Markdown table, header rule and all."""
    lines = [
        "| " + " | ".join(header) + " |",
        "|" + "|".join("---" for _ in header) + "|",
    ]
    lines.extend("| " + " | ".join(cell(item) for item in row) + " |" for row in rows)
    return "\n".join(lines)


def option_inputs(schema: Mapping[str, Any]) -> dict[str, str]:
    """Map each declared option to the Input cell an editable field prints.

    Args:
        schema: The projection's options JSON schema.

    Returns:
        Option name → ``input · <bounds>``. A payload field of the same name
        round-trips through that option and is therefore editable (ADR-K D-3).
    """
    properties: Mapping[str, Any] = schema.get("properties", {})
    return {name: f"input · {option_bounds(spec)}" for name, spec in properties.items()}


def options_table(schema: Mapping[str, Any]) -> str:
    """Render the knobs a caller may fill, from the options schema."""
    properties: Mapping[str, Any] = schema.get("properties", {})
    if not properties:
        return NO_OPTIONS
    rows = [
        (
            f"`{name}`",
            describe(collapse(spec)),
            option_bounds(spec),
            f"`{dumps(spec.get('default'))}`",
            spec.get("description", ""),
        )
        for name, spec in properties.items()
    ]
    return table(OPTION_HEADER, rows)


def inventory_table(fields: Sequence[InventoryField]) -> str:
    """Render one row per payload field, parents before their children."""
    rows = [
        (
            f"`{field.path}`",
            field.kind,
            field.presence,
            f"`{field.binding}`",
            field.state,
            field.interaction,
        )
        for field in fields
    ]
    return table(FIELD_HEADER, rows)


def interactive_fields(fields: Sequence[InventoryField]) -> tuple[str, ...]:
    """Return the paths of every field a caller can send back."""
    return tuple(field.path for field in fields if field.interaction != NONE)


def inputs_note(fields: Sequence[InventoryField]) -> str:
    """Name the fields a caller can send back, or say that none can."""
    editable = interactive_fields(fields)
    return ", ".join(f"`{path}`" for path in editable) if editable else READ_ONLY


__all__ = [
    "FIELD_HEADER",
    "INDEX_HEADER",
    "NO_OPTIONS",
    "OPTION_HEADER",
    "READ_ONLY",
    "cell",
    "inputs_note",
    "interactive_fields",
    "inventory_table",
    "option_inputs",
    "options_table",
    "table",
]
