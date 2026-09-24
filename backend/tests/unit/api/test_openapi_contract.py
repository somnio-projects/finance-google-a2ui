"""The OpenAPI document is part of the deliverable, so it is tested.

`.claude/rules/backend/api-design.md` requires every operation to carry a
summary, a description, a stable operation id, tags, documented responses and
documented parameters. These tests fail the moment a route is added without
them — the rule is enforced, not aspirational.

The projection half of the contract (ADR-K: one example per registered view,
an options schema, a discriminator literal) is asserted in
``test_openapi_projections.py``, and the `problem_responses` builder in
``test_openapi_helpers.py`` — same gate, split out to stay inside the
150-line budget.
"""

from typing import Any

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.openapi import PROBLEM_DESCRIPTIONS, TAGS_METADATA

#: Routes FastAPI generates for the documentation itself.
GENERATED = {"/openapi.json", "/docs", "/docs/oauth2-redirect", "/redoc"}

#: Unauthenticated by contract (`.claude/rules/backend/security.md`). Adding a
#: path here is a security decision: it needs a note in the feature spec and
#: the reviewer's sign-off, which is why the list is spelled out rather than
#: inferred from whether a route happens to declare a 401.
PUBLIC = {
    "/health",
    "/readyz",
    "/.well-known/agent-card.json",
    # Spec 0027: a person who cannot sign in yet has no token to present.
    "/v1/access-requests",
    "/v1/preview-sign-ins",
    # Spec 0043: the same reason, for the one question the sign-in screen has
    # to ask *before* it can ask anything else — which door this is.
    "/v1/sign-in-policy",
}


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
        assert statuses & {200, 201, 202, 204}, f"{where} documents no success response"
        errors = {status for status in statuses if status >= 400}
        assert errors, f"{where} documents no error response"
        assert errors <= set(PROBLEM_DESCRIPTIONS), (
            f"{where} has an undocumented status"
        )


def test_authenticated_operations_document_401(app: FastAPI) -> None:
    for path, method, operation in _operations(app):
        if path in PUBLIC:
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
    # FastAPI's 422 envelope was skipped by name; it is gone (spec 0038 OD-6).
    assert not {"HTTPValidationError", "ValidationError"} & set(schemas)
    for name, schema in schemas.items():
        assert schema.get("description"), f"schema {name} has no description"
        for field, spec in schema.get("properties", {}).items():
            described = spec.get("description") or any(
                option.get("description") for option in spec.get("anyOf", [])
            )
            assert described, f"{name}.{field} has no description"


def test_document_describes_the_service_and_its_tags(app: FastAPI) -> None:
    schema = app.openapi()
    assert "A2UI finance showcase" in schema["info"]["description"]
    assert schema["info"]["license"]["name"] == "Apache-2.0"
    assert {tag["name"] for tag in schema["tags"]} == {
        tag["name"] for tag in TAGS_METADATA
    }
    assert all(tag["description"] for tag in schema["tags"])


def test_every_non_public_route_actually_refuses_an_unauthenticated_call(
    unlimited_app: FastAPI, unlimited_client: TestClient
) -> None:
    """Documenting a 401 is not the same as enforcing one.

    The test above asserts every non-public operation *documents* a 401. A
    controller that copies the documented responses and forgets
    ``PrincipalDep`` would pass it while being wide open. This calls each
    route without a token and insists on being turned away, so a route cannot
    join the public set by omission — only by being named in ``PUBLIC``.
    """
    methods = {
        "GET": unlimited_client.get,
        "POST": unlimited_client.post,
        "PUT": unlimited_client.put,
    }
    checked = 0
    for path, method, _ in _operations(unlimited_app):
        call = methods.get(method.upper())
        if path in PUBLIC or call is None or "{" in path:
            continue
        checked += 1
        assert call(path).status_code == 401, f"{method.upper()} {path} is not guarded"
    assert checked, "no route was checked — the loop is not doing anything"
