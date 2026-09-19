"""Shared OpenAPI building blocks (`.claude/rules/backend/api-design.md`).

Every error response in this service is an RFC 9457 problem document, so the
`responses=` map of an operation is assembled from one place instead of being
copy-pasted into each controller: `problem_responses(...)` takes the statuses
a route can answer and returns the documented entries.
"""

from http import HTTPStatus
from typing import Any, Final

from app.core.errors import PROBLEM_TYPE_BASE
from app.schemas.problem import ProblemDetails

#: One sentence per status, written for the client developer reading `/docs`.
PROBLEM_DESCRIPTIONS: Final[dict[int, str]] = {
    400: "Malformed request (unreadable body or oversized payload).",
    401: "Missing, expired or unverifiable bearer token (`auth/*` codes).",
    403: "Authenticated but not allowed — a required scope (or MFA) is absent.",
    404: "Resource does not exist, or the endpoint is switched off by a feature flag.",
    409: "The request conflicts with the current state of the resource.",
    422: "Well-formed request that failed validation (`malformed-request`).",
    429: "Rate limit exceeded for this client or token.",
    500: "Unexpected error; reported to telemetry and masked for the caller.",
    503: "A dependency (database, identity provider) is unavailable.",
}

TAGS_METADATA: Final[list[dict[str, Any]]] = [
    {
        "name": "health",
        "description": (
            "Liveness and readiness probes. Unauthenticated by contract so "
            "orchestrators can reach them (ADR-B)."
        ),
    },
    {
        "name": "identity",
        "description": (
            "Who the bearer token belongs to and what that subject did. "
            "Every read is written to the audit trail."
        ),
    },
    {
        "name": "views",
        "description": (
            "Named, versioned projections of the portfolio (ADR-K): the "
            "catalog of what can be rendered, and the rendering itself. The "
            "backend shapes every payload; the client binds it unchanged."
        ),
    },
    {
        "name": "a2a",
        "description": (
            "The A2A protocol surface: JSON-RPC posted to the service root, "
            "plus the public agent card. **Not RESTful, on purpose** — it "
            "implements Google's protocol (ADR-J D-2/D-3). Errors here are "
            "JSON-RPC error objects, not RFC 9457 problem documents, so a "
            "client parses two shapes depending on the surface it is on."
        ),
    },
    {
        "name": "feature-flags",
        "description": (
            "Runtime switches for endpoints (spec 0002). Administrative: the "
            "token needs the `admin` scope — and, in production, an MFA `amr`."
        ),
    },
]

API_DESCRIPTION: Final[str] = (
    "Backend for the Somnio and Google **A2UI finance showcase**.\n\n"
    "Authentication: `Authorization: Bearer <token>` on every route except the "
    "health probes and this document. Errors are RFC 9457 problem documents "
    "(`application/problem+json`) carrying a stable `type` URI and the "
    "`request_id` echoed in the `X-Request-ID` header.\n\n"
    "Source and architecture: https://github.com/somnio-projects/finance-google-a2ui"
)


def problem_responses(*statuses: int) -> dict[int | str, dict[str, Any]]:
    """Return documented `application/problem+json` responses for ``statuses``.

    Args:
        statuses: HTTP status codes the operation can answer with.

    Returns:
        A mapping usable as FastAPI's ``responses=`` argument.

    Raises:
        KeyError: When a status has no description in ``PROBLEM_DESCRIPTIONS``.
    """
    return {
        status: {
            "model": ProblemDetails,
            "description": PROBLEM_DESCRIPTIONS[status],
            "content": {
                "application/problem+json": {
                    "example": {
                        "type": f"{PROBLEM_TYPE_BASE}{_code(status)}",
                        "title": HTTPStatus(status).phrase,
                        "status": status,
                        "detail": PROBLEM_DESCRIPTIONS[status],
                        "instance": "/v1/me",
                        "request_id": "3ed55388-087e-419f-acbe-34f663fc04c4",
                    }
                }
            },
        }
        for status in statuses
    }


def _code(status: int) -> str:
    """Map a status to the error code the API uses for it."""
    codes = {
        400: "malformed-request",
        401: "auth/missing-token",
        403: "forbidden",
        404: "feature-disabled",
        409: "conflict",
        422: "malformed-request",
        429: "rate-limited",
        500: "internal",
        503: "dependency-unavailable",
    }
    return codes[status]


#: Statuses every authenticated route can answer with, in addition to its own.
AUTHENTICATED: Final[tuple[int, ...]] = (401, 429, 500)

__all__ = [
    "API_DESCRIPTION",
    "AUTHENTICATED",
    "PROBLEM_DESCRIPTIONS",
    "TAGS_METADATA",
    "problem_responses",
]
