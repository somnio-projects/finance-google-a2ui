"""`docs/catalog/CONTRACT.md`, assembled from the registry (GGU-41).

The fifth consumer of the one registration ADR-K D-14 describes: alongside
OpenAPI, the ``/v1/views`` catalog, the prompt fragments and the A2UI adapter,
registering a projection also publishes it to the frozen design contract, with
no shared file edited (ADR-K D-15) — which is why the generator never holds a
list of components. Pure, like the rest of the layer: it renders a string and
reads no file, and the script under ``backend/scripts/`` touches the disk.
"""

from collections.abc import Sequence
from hashlib import sha256
from json import dumps
from typing import Final

from app.presentation.catalog_actions import actions_table
from app.presentation.catalog_guidance import guidance_note
from app.presentation.catalog_preamble import PREAMBLE
from app.presentation.catalog_tables import (
    INDEX_HEADER,
    inputs_note,
    inventory_table,
    options_table,
    table,
)
from app.presentation.contract import catalog_entry
from app.presentation.inventory import InventoryField
from app.presentation.published import component_of, inventory_of
from app.presentation.registry import Projection

#: Where the rendered document is checked in, relative to the repository root.
CONTRACT_PATH: Final[str] = "docs/catalog/CONTRACT.md"
#: How much of the sha256 the document prints. Twelve hex characters is a
#: fingerprint a human can compare by eye and still not collide by accident.
DIGEST_LENGTH: Final[int] = 12
#: Catalog keys that are *renderings* of facts the digest already covers —
#: the field inventory is the payload schema walked, the prompt fragment is
#: the summary, options and guidance joined. Hashing them too would move
#: every frozen `v1` digest the day a rendering changed its wording, while
#: nothing a client binds had moved (spec 0031 OD-2).
DERIVED_KEYS: Final[tuple[str, ...]] = ("fields", "prompt")


def digest(projection: Projection) -> str:
    """Fingerprint everything one projection promises.

    Args:
        projection: The registered projection to fingerprint.

    Returns:
        The first ``DIGEST_LENGTH`` hex characters of a sha256 over its id,
        summary, endpoints, options schema, payload schema and example — the
        frozen version identifier design and GGU-14 cite. If a ``v1`` digest
        moves, something frozen changed.
    """
    entry = dict(catalog_entry(projection))
    for derived in DERIVED_KEYS:
        del entry[derived]
    entry["payload_schema"] = projection.dto.model_json_schema()
    canonical = dumps(entry, sort_keys=True, default=str).encode()
    return sha256(canonical).hexdigest()[:DIGEST_LENGTH]


def fields_of(projection: Projection) -> tuple[InventoryField, ...]:
    """Return the field inventory of one projection's payload."""
    return inventory_of(projection)


def _section(projection: Projection) -> str:
    """Render the whole entry for one projection."""
    fields = fields_of(projection)
    meta = (
        f"> {projection.summary}\n\n"
        f"- **Frozen id:** `{projection.id}` · "
        f"**digest:** `{digest(projection)}`\n"
        # The component was the one fact this document did not carry, while
        # the snapshot and the A2UI surface both did — so design could not
        # check the name it had drawn against the name the client would
        # register (GGU-53, spec 0023 AC-2).
        f"- **Component:** `{component_of(projection)}`\n"
        f"- **Payload type:** `{projection.dto.__name__}`\n"
        f"- **Served by:** "
        + " · ".join(f"`{name}`" for name in projection.endpoints)
        + f"\n- **Editable fields:** {inputs_note(fields)}"
    )
    return "\n\n".join(
        (
            f"## `{projection.id}`",
            meta,
            "### Options",
            options_table(projection.options.model_json_schema()),
            "### Field inventory",
            inventory_table(fields),
            "### When the agent picks this",
            guidance_note(projection.guidance),
            "### Actions",
            actions_table(list(catalog_entry(projection)["actions"])),
            "### Example payload",
            "```json\n" + dumps(dict(projection.example), indent=2) + "\n```",
        )
    )


def _index(projections: Sequence[Projection]) -> str:
    """Render the one-line-per-component table the UI Kit cover cites."""
    rows = []
    for projection in projections:
        fields = fields_of(projection)
        rows.append(
            (
                f"[`{projection.id}`](#{projection.id.replace('.', '')})",
                f"`{component_of(projection)}`",
                f"`{digest(projection)}`",
                str(len(fields)),
                inputs_note(fields),
                projection.summary,
            )
        )
    return "## Components\n\n" + table(INDEX_HEADER, rows)


def contract_document(projections: Sequence[Projection]) -> str:
    """Render the frozen contract for every registered projection.

    Args:
        projections: The registry's contents, ordered by id.

    Returns:
        The full Markdown document, ending in exactly one newline.
    """
    parts = [PREAMBLE.rstrip("\n"), _index(projections)]
    parts.extend(_section(projection) for projection in projections)
    return "\n\n".join(parts) + "\n"


__all__ = [
    "CONTRACT_PATH",
    "DERIVED_KEYS",
    "DIGEST_LENGTH",
    "contract_document",
    "digest",
    "fields_of",
]
