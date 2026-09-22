"""What a route says about itself, read from its dependency tree (spec 0035).

`api.route_facts` is the audit's second source: the document is hand-declared
in each controller, so it can only be checked against something that is not the
document. These tests pin what that source reports for the real application.
"""

from fastapi import FastAPI

from app.api.route_facts import (
    FRAMEWORK_STATUSES,
    RouteFacts,
    answerable_statuses,
    route_facts,
)
from tests.unit.api.openapi_fixtures import facts


def _by_where(app: FastAPI) -> dict[str, RouteFacts]:
    return {fact.where: fact for fact in route_facts(app)}


def test_every_documented_operation_has_facts(app: FastAPI) -> None:
    found = route_facts(app)
    operations = {
        (path, method)
        for path, item in app.openapi()["paths"].items()
        for method in item
    }
    assert {(fact.path, fact.method) for fact in found} == operations
    assert len(found) == len(operations)


def test_the_documentation_routes_are_not_operations(app: FastAPI) -> None:
    paths = {fact.path for fact in route_facts(app)}
    assert "/openapi.json" not in paths
    assert "/docs" not in paths


def test_authentication_is_read_from_the_dependency_tree(app: FastAPI) -> None:
    found = _by_where(app)
    assert found["GET /v1/me"].authenticated is True
    assert found["GET /health"].authenticated is False


def test_the_feature_flag_that_guards_a_route_is_readable(app: FastAPI) -> None:
    found = _by_where(app)
    assert found["GET /v1/me/audit-events"].feature_key == "identity.audit"
    assert found["GET /v1/me"].feature_key is None


def test_a_body_and_a_parameter_are_both_recognised(app: FastAPI) -> None:
    found = _by_where(app)
    batch = found["POST /v1/view-renders"]
    assert batch.accepts_body is True
    assert batch.validates_input is True
    # The A2A route reads the raw request, so the body exists only in the
    # hand-written `openapi_extra` — and nothing about it is validated.
    rpc = found["POST /"]
    assert rpc.accepts_body is True
    assert rpc.validates_input is False


def test_a_session_route_is_seen_to_open_the_database(app: FastAPI) -> None:
    assert _by_where(app)["GET /v1/sessions"].uses_database is True


def test_where_names_the_operation_the_way_a_finding_does() -> None:
    assert facts(path="/v1/me", method="get").where == "GET /v1/me"


def test_operation_resolves_the_route_in_the_document(app: FastAPI) -> None:
    document = app.openapi()
    fact = _by_where(app)["GET /v1/me"]
    assert fact.operation(document)["operationId"] == "read_current_identity"


def test_the_answerable_statuses_are_derived_not_listed() -> None:
    assert answerable_statuses() == {401, 403, 404, 413, 422, 429, 500, 503}
    assert FRAMEWORK_STATUSES <= answerable_statuses()


def test_no_route_declares_a_status_nothing_answers(app: FastAPI) -> None:
    answerable = answerable_statuses()
    for fact in route_facts(app):
        fiction = {code for code in fact.declared if code >= 400} - answerable
        assert not fiction, f"{fact.where} declares {sorted(fiction)}"
