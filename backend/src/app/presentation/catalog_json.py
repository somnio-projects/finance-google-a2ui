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

from app.presentation.catalog_doc import digest
from app.presentation.prompt import view_fragment
from app.presentation.published import component_of, field_rows, guidance_of
from app.presentation.registry import Projection

#: Where the rendered snapshot is checked in, relative to the repository root.
SNAPSHOT_PATH: Final[str] = "docs/catalog/view-catalog.snapshot.json"
#: Shape version of the snapshot document itself, not of any projection. A
#: consumer reads this before anything else; the per-view freeze is the
#: versioned id plus its digest.
SNAPSHOT_VERSION: Final[int] = 1
#: The command that regenerates both catalog artefacts.
FIX_COMMAND: Final[str] = "cd backend && make catalog"


def snapshot_entry(projection: Projection) -> dict[str, Any]:
    """Describe one projection for a machine rather than for a reader.

    Args:
        projection: The registered projection to describe.

    Returns:
        Its component type, view id, digest, serving endpoints, DTO field
        paths, options schema, declared actions, prompt fragment and rendered
        example — what a client test needs to prove it binds the shape the
        backend serves.
    """
    example = dict(projection.example)
    return {
        "view": projection.id,
        "component": component_of(projection),
        "digest": digest(projection),
        "summary": projection.summary,
        "payload_type": projection.dto.__name__,
        "endpoints": list(projection.endpoints),
        "fields": field_rows(projection),
        "options_schema": projection.options.model_json_schema(),
        # Read off the rendered example, the same way `catalog_entry` does, so
        # a projection publishes its actions by rendering them and still edits
        # no shared file (ADR-K D-15). This key was missing while the Markdown
        # and `GET /v1/views` both carried it, and nothing noticed: each
        # artefact is diffed only against its own generator, so both were
        # internally consistent and disagreed with each other (GGU-92).
        "actions": list(example.get("actions", ())),
        # `null` where design has not written a do/don't pair yet, rather than
        # a sentence this backend invented for itself (`presentation.guidance`).
        "guidance": guidance_of(projection),
        # The lines the system prompt carries for this view, verbatim, so the
        # developer catalog shows what the model is taught (spec 0031).
        "prompt": view_fragment(projection),
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
    "snapshot_document",
    "snapshot_entry",
]
