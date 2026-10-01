"""Validate against the vendored A2UI v1.0 schemas (spec 0053 AC-1, AC-2).

The schemas in ``docs/a2ui/v1.0/schemas/`` reference the catalog by the
placeholder ``catalog.json``, relative to their own ``$id``; the finance
catalog in turn references ``common_types.json`` relative to **its** ``$id``.
The registry below serves both: every vendored schema under its own id and
its file name, the generated catalog under the placeholder and under its id,
and ``common_types.json`` once more beside the catalog's id. Nothing is
fetched over the network — an unresolvable reference is an error.

Shared by the unit and the integration suites, which both validate the bytes
the endpoint emits.
"""

import json
from functools import cache
from pathlib import Path
from typing import Any, Final

from jsonschema import Draft202012Validator
from referencing import Registry, Resource

from app.presentation.a2ui_v1.catalog import catalog
from app.presentation.a2ui_v1.wire import CATALOG_ID
from app.presentation.registry import REGISTRY
from app.presentation.views import LOADED

REPO_ROOT: Final[Path] = Path(__file__).resolve().parents[2]
V1_DIR: Final[Path] = REPO_ROOT / "docs" / "a2ui" / "v1.0"
SCHEMAS: Final[Path] = V1_DIR / "schemas"
EXAMPLES: Final[Path] = V1_DIR / "examples"
SPEC_BASE: Final[str] = "https://a2ui.org/specification/v1_0/"
CATALOG_BASE: Final[str] = CATALOG_ID.rsplit("/", 1)[0] + "/"


def load(path: Path) -> Any:
    """Return one JSON file, decoded."""
    return json.loads(path.read_text(encoding="utf-8"))


@cache
def registry() -> Registry:
    """Return the offline registry: vendored schemas plus the generated catalog."""
    assert LOADED, "the registry must be populated before the catalog renders"
    pairs: list[tuple[str, Resource]] = []
    for path in sorted(SCHEMAS.glob("*.json")):
        resource = Resource.from_contents(load(path))
        pairs += [(load(path)["$id"], resource), (SPEC_BASE + path.name, resource)]
    common = Resource.from_contents(load(SCHEMAS / "common_types.json"))
    finance = Resource.from_contents(catalog(REGISTRY.all()))
    pairs += [
        (CATALOG_BASE + "common_types.json", common),
        (SPEC_BASE + "catalog.json", finance),
        (CATALOG_ID, finance),
    ]
    return Registry().with_resources(pairs)


def validator(schema_file: str) -> Draft202012Validator:
    """Return a validator for one vendored schema, references resolved offline."""
    return Draft202012Validator(load(SCHEMAS / schema_file), registry=registry())


def errors(schema_file: str, instance: Any) -> list[str]:
    """Return every validation error of ``instance``, as readable lines."""
    return [
        f"{'/'.join(map(str, error.absolute_path))}: {error.message}"
        for error in validator(schema_file).iter_errors(instance)
    ]


__all__ = [
    "CATALOG_BASE",
    "EXAMPLES",
    "SCHEMAS",
    "V1_DIR",
    "errors",
    "load",
    "registry",
    "validator",
]
