"""`docs/a2ui/v1.0/finance.catalog.json` — the generated v1.0 catalog (ADR-M D-5).

A third rendering of the one registry read the frozen contract already makes,
listed in ``catalog_artifacts.ARTIFACTS`` beside ``CONTRACT.md`` and the
snapshot, so ``make catalog`` writes it and ``catalog-check`` fails the gate
when a projection moved and this file did not — no new script, no new gate
step.

The ``instructions`` are the prompt fragment the model is already taught
(``presentation.prompt``), verbatim: the catalog and the system prompt are two
renderings of one text, never two texts. There is no ``theme`` — v1.0 took it
off the wire, and theming lives in the client's ``ThemeData``.
"""

from collections.abc import Sequence
from json import dumps
from typing import Any, Final

from app.presentation.a2ui_v1.catalog_components import any_component, components
from app.presentation.a2ui_v1.catalog_functions import any_function, functions
from app.presentation.a2ui_v1.wire import CATALOG_ID, PROTOCOL_VERSION
from app.presentation.catalog_json import FIX_COMMAND
from app.presentation.prompt import prompt_fragment
from app.presentation.registry import Projection

JSON_SCHEMA: Final[str] = "https://json-schema.org/draft/2020-12/schema"
TITLE: Final[str] = "Finance showcase catalog"
DESCRIPTION: Final[str] = (
    "The A2UI v1.0 catalog of the Somnio x Google finance showcase: one "
    "component per projection family, plus Section. GENERATED from the "
    f"projection registry — do not edit by hand. Regenerate with: {FIX_COMMAND}"
)


def catalog(projections: Sequence[Projection]) -> dict[str, Any]:
    """Return the catalog document as an object.

    Args:
        projections: The registry's contents, ordered by id.

    Returns:
        A catalog that validates against the vendored
        ``catalog_definition.json``, with ``$id`` equal to ``catalogId``.
    """
    defined = components(projections)
    return {
        "$schema": JSON_SCHEMA,
        "$id": CATALOG_ID,
        "protocolVersion": PROTOCOL_VERSION,
        "title": TITLE,
        "description": DESCRIPTION,
        "catalogId": CATALOG_ID,
        "instructions": prompt_fragment(projections),
        "components": defined,
        "functions": functions(projections),
        "$defs": {
            "anyComponent": any_component(list(defined)),
            "anyFunction": any_function(),
        },
    }


def catalog_document(projections: Sequence[Projection]) -> str:
    """Render the catalog as the bytes ``make catalog`` checks in.

    Args:
        projections: The registry's contents, ordered by id.

    Returns:
        Indented JSON ending in exactly one newline. Key order is the order
        built above, which depends on the registry and nothing else.
    """
    return dumps(catalog(projections), indent=2, ensure_ascii=False) + "\n"


__all__ = ["DESCRIPTION", "TITLE", "catalog", "catalog_document"]
