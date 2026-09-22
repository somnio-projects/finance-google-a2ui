"""Every error response is one media type, and it is the one we answer.

`api.openapi_errors` folds FastAPI's `application/json` copy of a problem
document into the `application/problem+json` the service really sends, and
drops the 422 envelope FastAPI attaches to operations that validate nothing
(spec 0038 OD-3).
"""

from typing import Any

from fastapi import FastAPI

from app.api.openapi_errors import (
    VALIDATION_SCHEMAS,
    correct_error_responses,
    drop_validation_schemas,
)
from app.api.openapi_statuses import PLAIN_JSON, PROBLEM_JSON
from app.api.route_facts import route_facts
from tests.unit.api.openapi_fixtures import (
    PROBLEM_REF,
    document,
    facts,
    operation,
    problem,
)

ENVELOPE_REF = "#/components/schemas/HTTPValidationError"


def _fastapi_422() -> dict[str, Any]:
    return {
        "description": "Validation Error",
        "content": {PLAIN_JSON: {"schema": {"$ref": ENVELOPE_REF}}},
    }


def test_the_schema_moves_onto_the_media_type_we_answer() -> None:
    op = operation(responses={"200": {}, "401": problem(401, schema=False, plain=True)})
    served = document(op)
    correct_error_responses(served, [facts()])
    content = op["responses"]["401"]["content"]
    assert set(content) == {PROBLEM_JSON}
    assert content[PROBLEM_JSON]["schema"] == {"$ref": PROBLEM_REF}
    assert content[PROBLEM_JSON]["example"]


def test_a_problem_that_already_has_its_schema_keeps_it() -> None:
    op = operation(responses={"200": {}, "401": problem(401, plain=True)})
    op["responses"]["401"]["content"][PROBLEM_JSON]["schema"] = {"$ref": "kept"}
    correct_error_responses(document(op), [facts()])
    content = op["responses"]["401"]["content"]
    assert content[PROBLEM_JSON]["schema"] == {"$ref": "kept"}
    assert PLAIN_JSON not in content


def test_the_boilerplate_422_is_removed() -> None:
    op = operation(responses={"200": {}, "422": _fastapi_422()})
    correct_error_responses(document(op), [facts()])
    assert "422" not in op["responses"]


def test_a_declared_422_survives_as_a_problem_document() -> None:
    op = operation(responses={"200": {}, "422": problem(422, plain=True)})
    correct_error_responses(document(op), [facts()])
    assert set(op["responses"]["422"]["content"]) == {PROBLEM_JSON}


def test_a_success_response_is_left_alone() -> None:
    op = operation()
    before = dict(op["responses"]["200"])
    correct_error_responses(document(op), [facts()])
    assert op["responses"]["200"] == before


def test_the_envelope_schemas_go_once_nothing_points_at_them() -> None:
    served = document(operation())
    served["components"]["schemas"] = {name: {} for name in VALIDATION_SCHEMAS}
    drop_validation_schemas(served)
    assert served["components"]["schemas"] == {}


def test_the_envelope_schemas_stay_while_something_points_at_them() -> None:
    served = document(operation(responses={"200": {}, "422": _fastapi_422()}))
    served["components"]["schemas"] = {name: {} for name in VALIDATION_SCHEMAS}
    drop_validation_schemas(served)
    assert set(served["components"]["schemas"]) == set(VALIDATION_SCHEMAS)


def test_no_served_error_offers_a_shape_the_service_never_sends(app: FastAPI) -> None:
    served = app.openapi()
    for fact in route_facts(app):
        for code, entry in fact.operation(served)["responses"].items():
            content = entry.get("content") or {}
            if PROBLEM_JSON not in content:
                continue
            assert set(content) == {PROBLEM_JSON}, f"{fact.where} {code}"
            assert content[PROBLEM_JSON]["schema"] == {"$ref": PROBLEM_REF}
