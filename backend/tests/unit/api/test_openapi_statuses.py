"""Which statuses an operation owes, and which it may not claim (spec 0035 OD-1).

Every rule is provoked directly: a check that has only ever been seen to pass
has not been shown to reject, which is the defect `.claude/rules/ci-conventions.md`
§5 keeps finding one level up.
"""

from app.api.openapi_statuses import (
    PLAIN_JSON,
    PROBLEM_JSON,
    problem_shape_findings,
    required_statuses,
    status_findings,
)
from app.api.route_facts import answerable_statuses
from tests.unit.api.openapi_fixtures import facts, operation, problem

ANSWERABLE = answerable_statuses()


def _kinds(op: dict[str, object], **overrides: object) -> list[str]:
    found = status_findings(op, facts(**overrides), ANSWERABLE)
    return [f"{finding.kind}: {finding.detail}" for finding in found]


def test_a_plain_authenticated_route_owes_401_429_and_500() -> None:
    assert set(required_statuses(facts())) == {401, 429, 500}


def test_a_probe_owes_no_429_because_the_limiter_exempts_it() -> None:
    owed = required_statuses(facts(path="/health", authenticated=False))
    assert set(owed) == {500}


def test_each_capability_adds_the_status_it_can_answer() -> None:
    owed = required_statuses(
        facts(
            feature_key="views.read",
            accepts_body=True,
            validates_input=True,
            uses_database=True,
        )
    )
    assert set(owed) == {401, 404, 413, 422, 429, 500, 503}
    assert "views.read" in owed[404]


def test_a_missing_status_is_named_with_its_reason() -> None:
    op = operation(responses={"200": {}, "401": problem(401), "500": problem(500)})
    assert _kinds(op) == ["status-missing: 429: the rate limiter counts this path"]


def test_a_status_nothing_in_the_service_answers_is_fiction() -> None:
    op = operation(responses={**operation()["responses"], "409": problem(409)})
    assert _kinds(op) == ["status-unreachable: 409: nothing answers it"]


def test_a_status_this_route_cannot_answer_is_fiction_too() -> None:
    op = operation(responses={**operation()["responses"], "413": problem(413)})
    assert _kinds(op) == ["status-unreachable: 413: not on this route"]


def test_a_probe_that_documents_429_is_told_so() -> None:
    op = operation(responses={"200": {}, "429": problem(429), "500": problem(500)})
    assert _kinds(op, path="/readyz", authenticated=False) == [
        "status-unreachable: 429: not on this route"
    ]


def test_a_401_on_an_unauthenticated_route_is_fiction() -> None:
    op = operation(responses={"200": {}, "401": problem(401), "500": problem(500)})
    kinds = _kinds(op, path="/health", authenticated=False)
    assert "status-unreachable: 401: not on this route" in kinds


def test_a_422_in_fastapis_own_shape_is_reported() -> None:
    envelope = {"description": "Validation Error", "content": {PLAIN_JSON: {}}}
    op = operation(responses={**operation()["responses"], "422": envelope})
    assert _kinds(op, validates_input=True) == [
        "problem-shape: 422 is not a problem document"
    ]


def test_a_clean_operation_produces_nothing() -> None:
    assert _kinds(operation()) == []


def test_offering_the_plain_json_copy_beside_the_problem_is_reported() -> None:
    responses = {"401": problem(401, plain=True)}
    found = list(problem_shape_findings(responses, "GET /v1/things"))
    assert [finding.detail for finding in found] == [f"401 also offers {PLAIN_JSON}"]


def test_a_problem_with_no_schema_is_reported() -> None:
    responses = {"401": problem(401, schema=False)}
    found = list(problem_shape_findings(responses, "GET /v1/things"))
    assert [finding.detail for finding in found] == ["401 problem has no schema"]


def test_a_response_that_is_not_a_problem_is_not_judged() -> None:
    responses = {"200": {"content": {PLAIN_JSON: {}}}, "204": {}}
    assert list(problem_shape_findings(responses, "GET /v1/things")) == []
    assert PROBLEM_JSON not in str(responses)
