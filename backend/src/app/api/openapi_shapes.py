"""Shape questions the OpenAPI audit asks of a document (spec 0038).

Where an example may legitimately live, whether a component schema and each of
its properties is described, and which tags the document declares. Pure
functions over the document dictionary; `api.openapi_audit` asks them per
operation, so this file holds the *how* and that one holds the *rules*.
"""

from collections.abc import Iterator
from dataclasses import dataclass
from typing import Any

#: Where FastAPI and pydantic put a concrete value: the response itself, the
#: referenced model, or the items of an inline array (a list endpoint).
REF_PREFIX = "#/components/schemas/"


@dataclass(frozen=True, slots=True)
class Finding:
    """One thing the document lacks, named so the fix is obvious."""

    where: str
    kind: str
    detail: str

    def __str__(self) -> str:
        """``METHOD /path: kind — detail``, one line per finding."""
        return f"{self.where}: {self.kind} — {self.detail}"


def resolve(schema: dict[str, Any], document: dict[str, Any]) -> dict[str, Any]:
    """Follow a local ``$ref`` into ``components.schemas``, once."""
    ref = str(schema.get("$ref", ""))
    if not ref.startswith(REF_PREFIX):
        return schema
    schemas = document.get("components", {}).get("schemas", {})
    return schemas.get(ref.removeprefix(REF_PREFIX), {})


def _exampled(schema: dict[str, Any]) -> bool:
    """Whether a schema object carries an example of either spelling."""
    return bool(schema.get("example") or schema.get("examples"))


def has_example(media: dict[str, Any], document: dict[str, Any]) -> bool:
    """Whether a media-type object shows a concrete value anywhere.

    Args:
        media: One entry of a ``content`` map.
        document: The whole document, for resolving references.
    """
    if _exampled(media):
        return True
    resolved = resolve(media.get("schema") or {}, document)
    if _exampled(resolved):
        return True
    if resolved.get("type") == "array":
        return _exampled(resolve(resolved.get("items") or {}, document))
    return False


def _described(spec: dict[str, Any]) -> bool:
    """A property is described directly or on one of its ``anyOf`` options."""
    if spec.get("description"):
        return True
    return any(option.get("description") for option in spec.get("anyOf", []))


def schema_findings(document: dict[str, Any]) -> Iterator[Finding]:
    """Yield a finding per undescribed component schema or property.

    Every schema class carries a docstring and every field a ``description``
    (`api-design.md` §2) — including anything a framework generates, which is
    why nothing is skipped by name here.
    """
    schemas = document.get("components", {}).get("schemas", {})
    for name, schema in schemas.items():
        where = f"schema {name}"
        if not schema.get("description"):
            yield Finding(where, "schema", "has no description (docstring)")
        for field, spec in schema.get("properties", {}).items():
            if not _described(spec):
                yield Finding(where, "schema", f"property {field!r} has no description")


def declared_tags(document: dict[str, Any]) -> dict[str, str]:
    """Return ``{tag name: description}`` for the document's tag list."""
    return {tag["name"]: tag.get("description", "") for tag in document.get("tags", [])}


def summarise(findings: list[Finding]) -> str:
    """Count findings by kind, one line each, for the end of a report."""
    counts: dict[str, int] = {}
    for finding in findings:
        counts[finding.kind] = counts.get(finding.kind, 0) + 1
    return "\n".join(f"  {kind}: {count}" for kind, count in sorted(counts.items()))


__all__ = [
    "Finding",
    "declared_tags",
    "has_example",
    "resolve",
    "schema_findings",
    "summarise",
]
