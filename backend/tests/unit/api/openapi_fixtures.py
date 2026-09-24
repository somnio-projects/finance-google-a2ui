"""Hand-built pieces the OpenAPI audit suites feed to their pure functions.

The audit reads two things: facts about a route and an operation object. Both
are plain data, so every rule can be provoked directly instead of by inventing
a broken controller — which is what lets the suites prove the check *rejects*,
not only that it passes on today's tree (spec 0038, Test decision).
"""

from typing import Any

from app.api.route_facts import RouteFacts

PROBLEM_REF = "#/components/schemas/ProblemDetails"


def facts(**overrides: Any) -> RouteFacts:
    """A plausible authenticated GET, with any field replaced."""
    values: dict[str, Any] = {
        "path": "/v1/things",
        "method": "get",
        "authenticated": True,
        "uses_database": False,
        "validates_input": False,
        "accepts_body": False,
        "feature_key": None,
        "declared": frozenset(),
    }
    values.update(overrides)
    return RouteFacts(**values)


def problem(status: int, *, schema: bool = True, plain: bool = False) -> dict[str, Any]:
    """One error response, optionally as FastAPI leaves it before the fold."""
    media: dict[str, Any] = {"example": {"status": status}}
    if schema:
        media["schema"] = {"$ref": PROBLEM_REF}
    content: dict[str, Any] = {"application/problem+json": media}
    if plain:
        content["application/json"] = {"schema": {"$ref": PROBLEM_REF}}
    return {"description": "an error", "content": content}


def operation(**overrides: Any) -> dict[str, Any]:
    """An operation that passes every rule, with any member replaced."""
    values: dict[str, Any] = {
        "summary": "Read a thing",
        "description": "Reads one thing for the authenticated caller. Spec 0001 AC-1.",
        "operationId": "read_thing",
        "tags": ["things"],
        "responses": {
            "200": {
                "description": "the thing",
                "content": {
                    "application/json": {
                        "schema": {"type": "object"},
                        "example": {"id": 1},
                    }
                },
            },
            "401": problem(401),
            "429": problem(429),
            "500": problem(500),
        },
        "security": [{"bearerAuth": []}],
    }
    values.update(overrides)
    return values


def document(op: dict[str, Any], *, path: str = "/v1/things") -> dict[str, Any]:
    """A one-operation document carrying ``op`` at ``path``."""
    return {
        "paths": {path: {"get": op}},
        "tags": [{"name": "things", "description": "Things."}],
        "components": {"securitySchemes": {"bearerAuth": {"type": "http"}}},
    }
