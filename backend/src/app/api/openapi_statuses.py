"""Which error statuses an operation must — and must not — document.

Split from `api.openapi_audit` under the 150-line budget. The two questions
here are the ones that decide whether the document tells the truth about a
route: a status the route can answer and does not name is a gap; a status it
names and nothing in this service can produce is fiction (spec 0035 OD-1).
"""

from collections.abc import Iterator
from typing import Any, Final

from app.api.middleware.rate_limit import EXEMPT_PATHS
from app.api.openapi_shapes import Finding
from app.api.route_facts import RouteFacts

PROBLEM_JSON: Final[str] = "application/problem+json"
#: FastAPI's default media type, which it attaches to a ``model=`` response.
PLAIN_JSON: Final[str] = "application/json"


def _rate_limited(facts: RouteFacts) -> bool:
    """Whether the limiter counts this path — the probes are exempt by name."""
    return facts.path not in EXEMPT_PATHS


def required_statuses(facts: RouteFacts) -> dict[int, str]:
    """The error statuses a route must document, each with its reason.

    Args:
        facts: What the route's dependency tree says it does.
    """
    required = {500: "the catch-all handler"}
    if _rate_limited(facts):
        required[429] = "the rate limiter counts this path"
    if facts.authenticated:
        required[401] = "the route authenticates through PrincipalDep"
    if facts.feature_key:
        required[404] = f"the route is gated by the {facts.feature_key!r} flag"
    if facts.accepts_body:
        required[413] = "the body-limit middleware applies to a request body"
    if facts.validates_input:
        required[422] = "FastAPI validates a body, path or query parameter"
    if facts.uses_database:
        required[503] = "the route opens a database session"
    return required


def _unreachable(facts: RouteFacts, status: int) -> bool:
    """Whether a documented status is one *this* route can never answer."""
    return {
        401: not facts.authenticated,
        413: not facts.accepts_body,
        422: not facts.validates_input,
        429: not _rate_limited(facts),
    }.get(status, False)


def _missing_findings(facts: RouteFacts, documented: set[int]) -> Iterator[Finding]:
    """Statuses the route can answer and the controller did not name."""
    for status, why in required_statuses(facts).items():
        if status not in documented:
            yield Finding(facts.where, "status-missing", f"{status}: {why}")


def _fiction_findings(
    facts: RouteFacts, documented: set[int], answerable: frozenset[int]
) -> Iterator[Finding]:
    """Statuses the controller named that nothing — or not this route — answers."""
    for status in sorted(s for s in documented if s >= 400):
        if status not in answerable:
            yield Finding(
                facts.where, "status-unreachable", f"{status}: nothing answers it"
            )
        elif _unreachable(facts, status):
            yield Finding(
                facts.where, "status-unreachable", f"{status}: not on this route"
            )


def _validation_shape(responses: dict[str, Any], where: str) -> Iterator[Finding]:
    """A documented 422 is an RFC 9457 document, never FastAPI's envelope."""
    if "422" in responses and PROBLEM_JSON not in (
        responses["422"].get("content") or {}
    ):
        yield Finding(where, "problem-shape", "422 is not a problem document")


def status_findings(
    op: dict[str, Any], facts: RouteFacts, answerable: frozenset[int]
) -> Iterator[Finding]:
    """Documented statuses are exactly those the route can answer, in one shape.

    Args:
        op: The operation object from the document.
        facts: The route's facts.
        answerable: Every status the service can produce at all.
    """
    responses: dict[str, Any] = op["responses"]
    documented = {int(code) for code in responses if code.isdigit()}
    yield from _missing_findings(facts, documented)
    yield from _fiction_findings(facts, documented, answerable)
    yield from _validation_shape(responses, facts.where)
    yield from problem_shape_findings(responses, facts.where)


def problem_shape_findings(responses: dict[str, Any], where: str) -> Iterator[Finding]:
    """A problem document is the *only* thing an error response offers.

    ``problem_responses`` passes ``model=ProblemDetails``, and FastAPI attaches
    that schema to its own default media type — so every error used to offer
    ``application/json`` with a schema and no example beside
    ``application/problem+json`` with an example and no schema, while
    `api.errors` only ever answers the second. Neither half was usable alone
    (spec 0035 OD-3).

    Args:
        responses: The operation's ``responses`` object.
        where: How a finding names the operation.
    """
    for code, entry in responses.items():
        content: dict[str, Any] = entry.get("content") or {}
        if PROBLEM_JSON not in content:
            continue
        if PLAIN_JSON in content:
            yield Finding(where, "problem-shape", f"{code} also offers {PLAIN_JSON}")
        if not content[PROBLEM_JSON].get("schema"):
            yield Finding(where, "problem-shape", f"{code} problem has no schema")


__all__ = [
    "PLAIN_JSON",
    "PROBLEM_JSON",
    "problem_shape_findings",
    "required_statuses",
    "status_findings",
]
