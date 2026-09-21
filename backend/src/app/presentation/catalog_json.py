"""`docs/catalog/view-catalog.snapshot.json` — the contract a client loads (GGU-53).

The frozen contract already exists as Markdown, and Markdown is for people: a
Dart test cannot parse a table. This module renders **the same promise** as
JSON, from the same registry and in the same pass, so the Flutter catalog test
can assert against the shapes the backend actually serves.

One generator, one gate, no second source of truth: every value here is read
from the projection — the component name from its own A2UI adapter, the field
paths from the inventory the Markdown prints, the options schema and the
example from the projection itself. Nothing in this module names a view, a
component or a field, so the next chart appears in the snapshot with nothing
here edited (ADR-K D-14, D-15).
"""

from collections.abc import Sequence
from json import dumps
from typing import Any, Final

from app.presentation.catalog_doc import digest, fields_of
from app.presentation.component_name import component_of
from app.presentation.inventory import InventoryField
from app.presentation.registry import Projection
from app.presentation.schema_facts import NONE

#: Where the rendered snapshot is checked in, relative to the repository root.
SNAPSHOT_PATH: Final[str] = "docs/catalog/view-catalog.snapshot.json"
#: Shape version of the snapshot document itself, not of any projection. A
#: consumer reads this before anything else; the per-view freeze is the
#: versioned id plus its digest.
SNAPSHOT_VERSION: Final[int] = 1
#: The command that regenerates both catalog artefacts.
FIX_COMMAND: Final[str] = "cd backend && make catalog"


def _absent(cell: str) -> str | None:
    """Return ``None`` where the Markdown table prints its em-dash placeholder.

    The dash reads well in a table and is a trap in JSON: a client would have
    to compare against a punctuation mark to learn that a field drives no state
    and takes no input. Same fact, rendered for the reader of each artefact.
    """
    return None if cell == NONE else cell


def _field(field: InventoryField) -> dict[str, str | None]:
    """Describe one payload field, the same row the Markdown table prints."""
    return {
        "path": field.path,
        "type": field.kind,
        "presence": field.presence,
        "binding": field.binding,
        "state": _absent(field.state),
        "input": _absent(field.interaction),
    }


def snapshot_entry(projection: Projection) -> dict[str, Any]:
    """Describe one projection for a machine rather than for a reader.

    Args:
        projection: The registered projection to describe.

    Returns:
        Its component type, view id, digest, serving endpoints, DTO field
        paths, options schema and rendered example — what a client test needs
        to prove it binds the shape the backend serves.
    """
    example = dict(projection.example)
    return {
        "view": projection.id,
        "component": component_of(projection),
        "digest": digest(projection),
        "summary": projection.summary,
        "payload_type": projection.dto.__name__,
        "endpoints": list(projection.endpoints),
        "fields": [_field(row) for row in fields_of(projection)],
        "options_schema": projection.options.model_json_schema(),
        # Restored: PR #61 added this and PR #66 removed it again while
        # regenerating, together with the assertion that guarded it — which is
        # why seventeen checks stayed green. See GGU-92.
        "actions": list(example.get("actions", ())),
        "example": example,
    }


def snapshot_document(projections: Sequence[Projection]) -> str:
    """Render the machine-readable catalog of every registered projection.

    Args:
        projections: The registry's contents, ordered by id.

    Returns:
        The full JSON document, keys sorted so the bytes depend on the
        registry and on nothing else, ending in exactly one newline.
    """
    document = {
        "$comment": (
            f"GENERATED FILE — do not edit by hand. Regenerate with: {FIX_COMMAND}"
        ),
        "version": SNAPSHOT_VERSION,
        "source": "the projection registry in backend/src/app/presentation/",
        "views": [snapshot_entry(projection) for projection in projections],
    }
    return dumps(document, indent=2, sort_keys=True, ensure_ascii=False) + "\n"


__all__ = [
    "FIX_COMMAND",
    "SNAPSHOT_PATH",
    "SNAPSHOT_VERSION",
    "component_of",
    "snapshot_document",
    "snapshot_entry",
]
