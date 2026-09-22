"""The audit `make openapi-check` runs, and the findings it produces.

Two halves. The first is the property the gate exists for: the real document
has nothing to report. The second proves it *rejects* — one mutation per rule,
because a check that has only ever been green has not been shown to work
(`.claude/rules/ci-conventions.md` §5, one level up).
"""

from fastapi import FastAPI

from app.api.openapi_audit import MAX_SUMMARY, audit
from app.api.route_facts import route_facts
from tests.unit.api.openapi_fixtures import document, facts, operation


def _details(**overrides: object) -> list[str]:
    op = operation(**overrides)
    return [finding.detail for finding in audit(document(op), [facts()])]


def test_the_real_document_is_complete(app: FastAPI) -> None:
    assert audit(app.openapi(), route_facts(app)) == []


def test_a_clean_operation_is_accepted() -> None:
    assert _details() == []


def test_a_missing_summary_is_reported() -> None:
    assert "missing or over 60 characters" in _details(summary="")


def test_an_over_long_summary_is_reported() -> None:
    assert "missing or over 60 characters" in _details(summary="x" * (MAX_SUMMARY + 1))


def test_a_short_description_is_reported() -> None:
    assert "shorter than 40 characters" in _details(description="Reads a thing.")


def test_a_description_that_names_no_spec_is_reported() -> None:
    long_enough = "Reads one thing for the authenticated caller, and nothing else."
    assert "names no spec or ADR" in _details(description=long_enough)


def test_an_adr_reference_satisfies_the_description_rule() -> None:
    with_adr = "Reads one thing for the authenticated caller (ADR-K), and no more."
    assert _details(description=with_adr) == []


def test_a_missing_or_camel_case_operation_id_is_reported() -> None:
    assert "missing or not snake_case" in _details(operationId="readThing")
    assert "missing or not snake_case" in _details(operationId="")


def test_an_untagged_operation_is_reported() -> None:
    assert "no tag" in _details(tags=[])


def test_a_tag_the_document_never_declares_is_reported() -> None:
    assert "'ghost' is not declared with a description" in _details(tags=["ghost"])


def test_an_operation_with_no_success_response_is_reported() -> None:
    assert "no 2xx response" in _details(responses={"500": {}})


def test_a_success_with_no_body_is_reported() -> None:
    responses = {**operation()["responses"], "200": {"description": "the thing"}}
    assert "200 has no content" in _details(responses=responses)


def test_a_bodiless_success_is_allowed() -> None:
    responses = {**operation()["responses"], "204": {"description": "gone"}}
    del responses["200"]
    assert _details(responses=responses) == []


def test_a_success_without_a_schema_or_example_is_reported() -> None:
    responses = {
        **operation()["responses"],
        "200": {"description": "the thing", "content": {"application/json": {}}},
    }
    details = _details(responses=responses)
    assert "200 application/json has no schema" in details
    assert "200 application/json has no example" in details


def test_a_request_body_without_an_example_is_reported() -> None:
    body = {"content": {"application/json": {"schema": {"type": "object"}}}}
    assert "request application/json has no example" in _details(requestBody=body)


def test_an_undescribed_parameter_is_reported() -> None:
    parameters = [{"name": "limit", "in": "query"}]
    assert "'limit' has no description" in _details(parameters=parameters)


def test_a_security_declaration_that_disagrees_with_the_route_is_reported() -> None:
    op = operation()
    del op["security"]
    found = audit(document(op), [facts()])
    assert "declaration disagrees with PrincipalDep" in [f.detail for f in found]


def test_a_document_with_no_scheme_for_its_authenticated_routes_is_reported() -> None:
    served = document(operation())
    del served["components"]["securitySchemes"]
    found = audit(served, [facts()])
    assert "no securitySchemes declared" in [finding.detail for finding in found]
