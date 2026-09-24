"""The document the service actually serves (spec 0038 OD-2).

`/openapi.json` and `/docs` are part of the deliverable, so they are asserted
like a route: they answer, they cover every operation the routers carry, and
they declare the bearer scheme on exactly the routes that enforce it.
"""

from fastapi import FastAPI
from fastapi.testclient import TestClient

from app.api.openapi_document import BEARER, apply_security, finalise, install
from app.api.route_facts import route_facts
from tests.unit.api.openapi_fixtures import document, facts, operation


def test_the_document_and_the_interactive_page_both_answer(client: TestClient) -> None:
    served = client.get("/openapi.json")
    assert served.status_code == 200
    assert client.get("/docs").status_code == 200
    assert served.json()["info"]["title"]


def test_the_document_covers_every_operation_the_routers_carry(
    app: FastAPI, client: TestClient
) -> None:
    served = client.get("/openapi.json").json()
    operations = [
        (path, method) for path, item in served["paths"].items() for method in item
    ]
    assert len(operations) == len(route_facts(app))
    assert len(operations) == 24, "a route was added or removed — update the spec"


def test_the_bearer_scheme_is_declared_and_required_where_it_is_enforced(
    app: FastAPI,
) -> None:
    served = app.openapi()
    assert served["components"]["securitySchemes"][BEARER]["scheme"] == "bearer"
    for fact in route_facts(app):
        declared = bool(fact.operation(served).get("security"))
        assert declared is fact.authenticated, fact.where


def test_a_public_route_carries_no_security_requirement(app: FastAPI) -> None:
    assert "security" not in app.openapi()["paths"]["/health"]["get"]


def test_fastapis_own_validation_envelope_is_gone(app: FastAPI) -> None:
    schemas = app.openapi()["components"]["schemas"]
    assert "HTTPValidationError" not in schemas
    assert "ValidationError" not in schemas


def test_the_document_is_built_once_and_reused(app: FastAPI) -> None:
    assert app.openapi() is app.openapi()


def test_installing_twice_still_yields_one_document() -> None:
    app = FastAPI()
    install(app)
    first = app.openapi()
    install(app)
    assert app.openapi() is first


def test_a_service_with_no_authenticated_route_declares_no_scheme() -> None:
    op = operation()
    del op["security"]
    served = document(op)
    del served["components"]["securitySchemes"]
    apply_security(served, [facts(authenticated=False)])
    assert "securitySchemes" not in served["components"]
    assert "security" not in served["paths"]["/v1/things"]["get"]


def test_finalise_returns_the_document_it_was_given() -> None:
    served = document(operation())
    assert finalise(served, [facts()]) is served
