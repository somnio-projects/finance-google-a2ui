"""Conditional requests: strong `ETag`, `Cache-Control` and 304 (ADR-K D-20).

A projection is a pure function of *(resource version, view, options, `as_of`)*,
so the same request answers the same bytes for the life of a session — the
cheapest possible cache key. This module is the one place that turns those
four facts into an entity tag and decides whether the caller already has the
body.

It is a **dependency plus two functions**, not a block of code inside a
controller, exactly as `.claude/rules/backend/api-design.md` §3 requires of any
cross-cutting behaviour: the next read endpoint gets revalidation by adding one
parameter and one call, and the comparison rules are tested once instead of
being re-derived per route.
"""

import json
from hashlib import sha256
from http import HTTPStatus
from typing import Annotated, Any, Final

from fastapi import Depends, Header, Response

#: `private` because every body is subject-scoped, and `no-cache` because a
#: feature flag can switch a route off at any moment: the client may keep the
#: body but must ask before reusing it. A `max-age` would let a switched-off
#: endpoint keep rendering client-side for the length of the window.
CACHE_CONTROL: Final[str] = "private, no-cache"
#: A body is subject-scoped, so an intermediary must never key on the URL
#: alone. `Cache-Control: private` already says so; this says it twice,
#: because the failure mode is serving one caller's portfolio to another.
VARY: Final[str] = "Authorization"

#: Documented on every operation that revalidates, so the 304 is part of the
#: contract rather than a surprise a client discovers in production.
NOT_MODIFIED_RESPONSE: Final[dict[int | str, dict[str, Any]]] = {
    304: {
        "description": (
            "The caller's `If-None-Match` matches the current entity tag; the "
            "body is unchanged and is not sent again."
        )
    }
}


def strong_etag(*parts: object) -> str:
    """Return a strong RFC 9110 entity tag over ``parts``.

    Args:
        parts: Everything the body is a function of, in a stable order —
            for a projection read: the resource, the view ids, the options
            and ``as_of`` (ADR-K D-20).

    Returns:
        The quoted tag, with no ``W/`` prefix: the bytes are reproduced
        exactly, so the comparison may be strong.
    """
    material = json.dumps(parts, sort_keys=True, default=str, separators=(",", ":"))
    return f'"{sha256(material.encode()).hexdigest()}"'


def matches(header: str | None, etag: str) -> bool:
    """Return True when ``header`` claims the caller already holds ``etag``.

    Args:
        header: The raw ``If-None-Match`` value, or None when absent.
        etag: The entity tag of the response about to be sent.

    Returns:
        True for ``*``, or when any listed tag equals ``etag``. Comparison is
        weak per RFC 9110 §13.1.2 — a client that echoes ``W/"x"`` for our
        strong ``"x"`` is asking about the same representation.
    """
    if header is None:
        return False
    candidates = {tag.strip().removeprefix("W/") for tag in header.split(",")}
    return "*" in candidates or etag in candidates


class ConditionalResponse:
    """Serve an entity tag, and answer 304 when the caller already has it."""

    def __init__(self, response: Response, if_none_match: str | None) -> None:
        """Bind to this request's outgoing response and its validator header."""
        self._response = response
        self._if_none_match = if_none_match

    def resolve[BodyT](self, body: BodyT, *, etag: str) -> BodyT | Response:
        """Return ``body`` with its validators, or an empty 304.

        Args:
            body: Whatever the route would answer with — a DTO, or a list
                of them; this helper never inspects it.
            etag: Its strong entity tag, from ``strong_etag``.

        Returns:
            The body itself when the caller does not already hold it — the
            route's ``response_model`` still validates it — otherwise a bare
            304 carrying the same validators, as RFC 9110 §15.4.5 requires.
        """
        validators = {"ETag": etag, "Cache-Control": CACHE_CONTROL, "Vary": VARY}
        self._response.headers.update(validators)
        if matches(self._if_none_match, etag):
            return Response(status_code=HTTPStatus.NOT_MODIFIED, headers=validators)
        return body


def get_conditional_response(
    response: Response,
    if_none_match: Annotated[
        str | None,
        Header(
            alias="If-None-Match",
            max_length=512,
            description=(
                "Entity tag the client already holds, from a previous `ETag`. "
                "A match answers 304 with no body (ADR-K D-20)."
            ),
            examples=['"5f2b1c8e…"'],
        ),
    ] = None,
) -> ConditionalResponse:
    """Provide the conditional-request helper bound to this request."""
    return ConditionalResponse(response, if_none_match)


ConditionalDep = Annotated[ConditionalResponse, Depends(get_conditional_response)]

__all__ = [
    "CACHE_CONTROL",
    "NOT_MODIFIED_RESPONSE",
    "VARY",
    "ConditionalDep",
    "ConditionalResponse",
    "get_conditional_response",
    "matches",
    "strong_etag",
]
