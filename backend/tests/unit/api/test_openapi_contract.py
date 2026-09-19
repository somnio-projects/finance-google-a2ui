"""The OpenAPI document is part of the deliverable, so it is tested.

`.claude/rules/backend/api-design.md` requires every operation to carry a
summary, a description, a stable operation id, tags, documented responses and
documented parameters. These tests fail the moment a route is added without
them — the rule is enforced, not aspirational.

The projection half of the contract (ADR-K: one example per registered view,
an options schema, a discriminator literal) is asserted in
``test_openapi_projections.py`` — same gate, split out to stay inside the
150-line budget.
"""

from typing import Any

import pytest
from fastapi import FastAPI

from app.api.openapi import PROBLEM_DESCRIPTIONS, TAGS_METADATA, problem_responses

#: Routes FastAPI generates for the documentation itself.
GENERATED = {"/openapi.json", "/docs", "/docs/oauth2-redirect", "/redoc"}


def _operations(app: FastAPI) -> list[tuple[str, str, dict[str, Any]]]:
    schema = app.openapi()
    return [
        (path, method, operation)
        for path, item in schema["paths"].items()
        if path not in GENERATED
        for method, operation in item.items()
    ]


def test_every_operation_is_fully_documented(app: FastAPI) -> None:
    for path, method, operation in _operations(app):
        where = f"{method.upper()} {path}"
        assert operation.get("summary"), f"{where} has no summary"
        assert len(operation.get("description", "")) > 40, (
            f"{where} needs a description"
        )
        assert operation.get("operationId"), f"{where} has no operation_id"
        assert operation.get("tags"), f"{where} has no tag"
        assert operation["tags"][0] in {tag["name"] for tag in TAGS_METADATA}


def test_every_operation_documents_its_error_responses(app: FastAPI) -> None:
    for path, method, operation in _operations(app):
        where = f"{method.upper()} {path}"
        statuses = {int(code) for code in operation["responses"] if code.isdigit()}
        assert statuses & {200, 201, 204}, f"{where} documents no success response"
        errors = {status for status in statuses if status >= 400}
        assert errors, f"{where} documents no error response"
        assert errors <= set(PROBLEM_DESCRIPTIONS), (
            f"{where} has an undocumented status"
        )


def test_authenticated_operations_document_401(app: FastAPI) -> None:
    for path, method, operation in _operations(app):
        if path in {"/healthz", "/readyz"}:
            continue
        assert "401" in operation["responses"], f"{method.upper()} {path} misses 401"


def test_every_parameter_is_described(app: FastAPI) -> None:
    for path, method, operation in _operations(app):
        for parameter in operation.get("parameters", []):
            assert parameter.get("description"), (
                f"{method.upper()} {path}: parameter "
                f"{parameter['name']} has no description"
            )


def test_every_schema_property_is_described(app: FastAPI) -> None:
    schemas = app.openapi()["components"]["schemas"]
    for name, schema in schemas.items():
        if name.startswith(("HTTPValidationError", "ValidationError")):
            continue  # FastAPI's built-in 422 envelope
        assert schema.get("description"), f"schema {name} has no description"
        for field, spec in schema.get("properties", {}).items():
            described = spec.get("description") or any(
                option.get("description") for option in spec.get("anyOf", [])
            )
            assert described, f"{name}.{field} has no description"


def test_problem_responses_are_built_from_one_place() -> None:
    built = problem_responses(401, 503)
    assert set(built) == {401, 503}
    assert built[401]["description"] == PROBLEM_DESCRIPTIONS[401]
    assert built[401]["model"].__name__ == "ProblemDetails"
    example = built[503]["content"]["application/problem+json"]["example"]
    assert example["type"] == "https://errors.finance-a2ui/dependency-unavailable"
    assert example["status"] == 503


def test_problem_responses_rejects_an_undocumented_status() -> None:
    with pytest.raises(KeyError, match="418"):
        problem_responses(418)


def test_document_describes_the_service_and_its_tags(app: FastAPI) -> None:
    schema = app.openapi()
    assert "A2UI finance showcase" in schema["info"]["description"]
    assert schema["info"]["license"]["name"] == "Apache-2.0"
    assert {tag["name"] for tag in schema["tags"]} == {
        tag["name"] for tag in TAGS_METADATA
    }
    assert all(tag["description"] for tag in schema["tags"])
