"""The rules an OpenAPI operation must satisfy, checked against the route.

`api-design.md` §2 says what every operation carries; this module is that
paragraph as code. Each rule reads the operation *and* the facts
`api.route_facts` derived from the route's dependency tree, so a status is
required because the route can produce it and forbidden because it cannot —
not because a list somewhere says so (spec 0035 OD-1). The status rules live
in `api.openapi_statuses`; `scripts/check_openapi.py` runs the whole audit in
the gate and prints every finding by name.
"""

import re
from collections.abc import Iterator, Sequence
from typing import Any, Final

from app.api.openapi_shapes import (
    Finding,
    declared_tags,
    has_example,
    schema_findings,
)
from app.api.openapi_statuses import status_findings
from app.api.route_facts import RouteFacts, answerable_statuses

MAX_SUMMARY: Final[int] = 60
MIN_DESCRIPTION: Final[int] = 40
#: A description names the spec or ADR it implements (`api-design.md` §2).
SPEC_REFERENCE: Final[re.Pattern[str]] = re.compile(
    r"(?i)\bspec\s+\d{4}\b|\bADR-[A-Z]\b"
)
OPERATION_ID: Final[re.Pattern[str]] = re.compile(r"^[a-z][a-z0-9_]*$")
#: Success statuses that carry no body by contract, so no schema is owed.
BODILESS: Final[frozenset[str]] = frozenset({"202", "204", "304"})


def _identity(op: dict[str, Any], where: str) -> Iterator[Finding]:
    """Summary, description and operation id."""
    summary = str(op.get("summary", ""))
    if not summary or len(summary) > MAX_SUMMARY:
        yield Finding(where, "summary", f"missing or over {MAX_SUMMARY} characters")
    description = str(op.get("description", ""))
    if len(description) < MIN_DESCRIPTION:
        yield Finding(
            where, "description", f"shorter than {MIN_DESCRIPTION} characters"
        )
    elif not SPEC_REFERENCE.search(description):
        yield Finding(where, "description", "names no spec or ADR")
    if not OPERATION_ID.match(str(op.get("operationId", ""))):
        yield Finding(where, "operation-id", "missing or not snake_case")


def _tags(
    op: dict[str, Any], where: str, declared: dict[str, str]
) -> Iterator[Finding]:
    """Every tag is one the application declares with a description."""
    tags = op.get("tags") or []
    if not tags:
        yield Finding(where, "tag", "no tag")
    for tag in tags:
        if not declared.get(tag):
            yield Finding(where, "tag", f"{tag!r} is not declared with a description")


def _media(
    content: dict[str, Any], document: dict[str, Any], where: str, kind: str, code: str
) -> Iterator[Finding]:
    """Every media type of a body shows a schema and an example."""
    for media_type, media in content.items():
        if not media.get("schema"):
            yield Finding(where, kind, f"{code} {media_type} has no schema")
        if not has_example(media, document):
            yield Finding(where, kind, f"{code} {media_type} has no example")


def _request_body(
    op: dict[str, Any], document: dict[str, Any], where: str
) -> Iterator[Finding]:
    """A body shows a schema and an example, per media type."""
    if body := op.get("requestBody"):
        yield from _media(body["content"], document, where, "request-body", "request")


def _successes(
    op: dict[str, Any], document: dict[str, Any], where: str
) -> Iterator[Finding]:
    """There is a 2xx, and each one carries a body unless it is bodiless."""
    codes = [code for code in op["responses"] if code.startswith("2")]
    if not codes:
        yield Finding(where, "success-response", "no 2xx response")
    for code in codes:
        content = op["responses"][code].get("content") or {}
        if content:
            yield from _media(content, document, where, "success-response", code)
        elif code not in BODILESS:
            yield Finding(where, "success-response", f"{code} has no content")


def _parameters(op: dict[str, Any], where: str) -> Iterator[Finding]:
    """Every query, path and header parameter is described."""
    for parameter in op.get("parameters", []):
        if not parameter.get("description"):
            yield Finding(
                where, "parameter", f"{parameter['name']!r} has no description"
            )


def _security(op: dict[str, Any], facts: RouteFacts) -> Iterator[Finding]:
    """The bearer requirement is declared on exactly the routes that enforce it."""
    if bool(op.get("security")) != facts.authenticated:
        yield Finding(
            facts.where, "security", "declaration disagrees with PrincipalDep"
        )


def audit(document: dict[str, Any], facts: Sequence[RouteFacts]) -> list[Finding]:
    """Return every finding of the document against the routes' facts.

    Args:
        document: ``app.openapi()``.
        facts: ``route_facts(app)`` for the same application.
    """
    tags, answerable = declared_tags(document), answerable_statuses()
    findings: list[Finding] = []
    for fact in facts:
        op = fact.operation(document)
        findings.extend(_identity(op, fact.where))
        findings.extend(_tags(op, fact.where, tags))
        findings.extend(status_findings(op, fact, answerable))
        findings.extend(_request_body(op, document, fact.where))
        findings.extend(_successes(op, document, fact.where))
        findings.extend(_parameters(op, fact.where))
        findings.extend(_security(op, fact))
    schemes = document.get("components", {}).get("securitySchemes")
    if any(fact.authenticated for fact in facts) and not schemes:
        findings.append(Finding("document", "security", "no securitySchemes declared"))
    findings.extend(schema_findings(document))
    return findings


__all__ = ["BODILESS", "MAX_SUMMARY", "MIN_DESCRIPTION", "audit"]
