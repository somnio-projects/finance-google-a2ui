"""The document the service serves, finished where FastAPI stops (spec 0035).

FastAPI derives nearly all of `/openapi.json` from the routes. What it cannot
derive here is the **bearer requirement**: authentication is a plain
``Authorization`` header dependency, not one of FastAPI's ``security`` classes,
so nothing told the document that `/v1/**` needs a token — `/docs` showed no
*Authorize* button and a generated client sent none. The scheme is declared
once and required on exactly the operations whose dependency tree contains
``get_current_principal``: read from the route, never from a list (OD-2).

The error-response corrections live next door in `api.openapi_errors`. Both
halves are re-derived from `api.route_facts` on every build, so neither can
describe a route that has since changed.
"""

from collections.abc import Sequence
from typing import Any, Final

from fastapi import FastAPI

from app.api.openapi_errors import correct_error_responses, drop_validation_schemas
from app.api.route_facts import RouteFacts, route_facts

#: The name the scheme is declared and referenced under.
BEARER: Final[str] = "bearerAuth"

#: The service's one security scheme (`backend/docs/AUTH.md`).
BEARER_SCHEME: Final[dict[str, Any]] = {
    "type": "http",
    "scheme": "bearer",
    "bearerFormat": "JWT",
    "description": (
        "`Authorization: Bearer <token>` — a Firebase/OIDC ID token verified "
        "through JWKS, or an HS256 service token for local and "
        "service-to-service use. Missing, expired or unverifiable answers 401 "
        "with an `auth/*` code."
    ),
}


def apply_security(document: dict[str, Any], facts: Sequence[RouteFacts]) -> None:
    """Declare the bearer scheme and require it where the route enforces it.

    Args:
        document: The document, modified in place.
        facts: ``route_facts(app)`` for the same application.
    """
    authenticated = [fact for fact in facts if fact.authenticated]
    for fact in authenticated:
        fact.operation(document)["security"] = [{BEARER: []}]
    if authenticated:
        components: dict[str, Any] = document.setdefault("components", {})
        components.setdefault("securitySchemes", {})[BEARER] = BEARER_SCHEME


def finalise(document: dict[str, Any], facts: Sequence[RouteFacts]) -> dict[str, Any]:
    """Apply every correction in place and return the same document.

    Args:
        document: What FastAPI built.
        facts: ``route_facts(app)`` for the same application.
    """
    apply_security(document, facts)
    correct_error_responses(document, facts)
    drop_validation_schemas(document)
    return document


def install(app: FastAPI) -> None:
    """Make ``app.openapi()`` serve the finished document.

    Args:
        app: The application, already carrying its routers.
    """

    def build() -> dict[str, Any]:
        """Build once and keep it on the app, exactly as FastAPI memoises."""
        if app.openapi_schema is None:
            app.openapi_schema = finalise(FastAPI.openapi(app), route_facts(app))
        return app.openapi_schema

    app.openapi = build


__all__ = ["BEARER", "BEARER_SCHEME", "apply_security", "finalise", "install"]
