"""What each route can answer, read from the route — never from its docs.

The OpenAPI document is hand-declared in every controller (`responses=`), so
it can only be checked against a *second* source. This module is that source:
it walks each route's dependency tree and records the facts that decide which
statuses the route can really produce — whether it authenticates, whether it
opens a database session, whether FastAPI validates anything, whether a
feature flag guards it. `api.openapi_audit` compares the declaration with
these facts, and `api.openapi_document` reads them to declare the bearer
scheme on exactly the routes that enforce it (spec 0035 OD-1, OD-2).
"""

from collections.abc import Iterator, Sequence
from dataclasses import dataclass
from typing import Any, Final

from fastapi import FastAPI
from fastapi.dependencies.models import Dependant
from fastapi.routing import APIRoute, RouteContext, iter_route_contexts

from app.api.deps import get_current_principal, get_session
from app.api.feature_gate import FeatureGate
from app.core.errors import AppError

#: Statuses produced outside the error hierarchy: the body-limit middleware
#: (413), FastAPI's request validation, translated to a problem document
#: (422), and the catch-all handler for anything unexpected (500).
FRAMEWORK_STATUSES: Final[frozenset[int]] = frozenset({413, 422, 500})


@dataclass(frozen=True, slots=True)
class RouteFacts:
    """One operation and what its dependency tree says it can do."""

    path: str
    method: str
    authenticated: bool
    uses_database: bool
    validates_input: bool
    accepts_body: bool
    feature_key: str | None
    declared: frozenset[int]

    @property
    def where(self) -> str:
        """``METHOD /path`` — how a finding names the operation."""
        return f"{self.method.upper()} {self.path}"

    def operation(self, document: dict[str, Any]) -> dict[str, Any]:
        """The operation object this route contributes to ``document``.

        Args:
            document: ``app.openapi()`` for the same application.
        """
        return document["paths"][self.path][self.method]


def _tree(dependant: Dependant) -> Iterator[Dependant]:
    """Yield the dependant and every sub-dependant beneath it, depth first."""
    yield dependant
    for sub in dependant.dependencies:
        yield from _tree(sub)


def _feature_key(calls: Sequence[object]) -> str | None:
    """Return the flag key of the first gate in the tree, if any."""
    for call in calls:
        if isinstance(call, FeatureGate):
            return call.key
    return None


def _declared(responses: dict[int | str, Any]) -> frozenset[int]:
    """Statuses the controller named in ``responses=``, as integers."""
    return frozenset(int(code) for code in responses if str(code).isdigit())


def _facts_of(route: RouteContext, method: str) -> RouteFacts:
    """Read one operation's facts off its effective route.

    ``route`` is the view FastAPI's own document builder reads: the path
    carries the router prefix and the dependant carries router-level
    ``dependencies=``, which the bare ``APIRoute`` does not.
    """
    nodes = list(_tree(route.dependant))
    calls = [node.call for node in nodes]
    extra: dict[str, Any] = route.openapi_extra or {}
    body_field: object | None = route.body_field
    return RouteFacts(
        path=route.path or "",
        method=method.lower(),
        authenticated=get_current_principal in calls,
        uses_database=get_session in calls,
        validates_input=body_field is not None
        or any(node.path_params or node.query_params for node in nodes),
        accepts_body=body_field is not None or "requestBody" in extra,
        feature_key=_feature_key(calls),
        declared=_declared(route.responses),
    )


def route_facts(app: FastAPI) -> tuple[RouteFacts, ...]:
    """Return the facts of every documented operation, in route order.

    Args:
        app: The built application. Included routers are resolved the way
            the document builder resolves them (``iter_route_contexts``);
            only ``APIRoute``s that appear in the schema are read, so
            FastAPI's own `/docs` routes are skipped.
    """
    return tuple(
        _facts_of(route, method)
        for route in iter_route_contexts(app.routes)
        if isinstance(route.original_route, APIRoute) and route.include_in_schema
        for method in sorted(route.methods or ())
    )


def _subclasses(cls: type[AppError]) -> Iterator[type[AppError]]:
    """Yield every descendant of ``cls``, depth first."""
    for sub in cls.__subclasses__():
        yield sub
        yield from _subclasses(sub)


def answerable_statuses() -> frozenset[int]:
    """Every error status this service can answer, derived, not listed.

    The error hierarchy carries a status per class and the API layer answers
    exactly those; the framework adds three more. A controller that declares
    anything else describes a response nobody can produce.
    """
    raised = {cls.status.value for cls in (AppError, *_subclasses(AppError))}
    return frozenset(raised) | FRAMEWORK_STATUSES


__all__ = ["FRAMEWORK_STATUSES", "RouteFacts", "answerable_statuses", "route_facts"]
