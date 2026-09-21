"""The registry rendered into OpenAPI (ADR-K D-4, D-14).

The response type of a multi-view read is a **discriminated union**: every
payload carries a ``view`` literal, the document shows ``oneOf`` with a
``discriminator``, and a generated client gets real types instead of ``Any``.

Both the union and the examples are **derived from the registry**, so adding a
chart publishes it to the document with no shared file edited (ADR-K D-15).
Hand-writing either would reintroduce exactly the list this design removes.
"""

import operator
from collections.abc import Mapping, Sequence
from datetime import datetime
from functools import reduce
from typing import Annotated, Any

from pydantic import BaseModel, Field, create_model

from app.presentation.published import component_of, guidance_of
from app.presentation.registry import Projection


def payload_annotation(projections: Sequence[Projection]) -> Any:
    """Return the discriminated union over ``projections``' payload types.

    Args:
        projections: Every registered projection. Two or more make a union;
            the service registers more than that before a route is declared.

    Returns:
        The annotation pydantic turns into ``oneOf`` plus a ``discriminator``.
    """
    members = reduce(operator.or_, (projection.dto for projection in projections))
    return Annotated[members, Field(discriminator="view")]


def _keyed(payload: Any) -> Any:
    """Return the ``dict[str, payload]`` annotation of the keyed object."""
    return dict[str, payload]


def views_response_model(
    projections: Sequence[Projection], *, name: str
) -> type[BaseModel]:
    """Build the documented response model of a multi-view read (ADR-K D-17).

    Args:
        projections: Every registered projection.
        name: Schema name shown in the OpenAPI document.

    Returns:
        A model with ``as_of``, ``portfolio_id`` and a ``views`` object keyed
        by view id, each value a member of the discriminated union.
    """
    return create_model(
        name,
        __doc__=(
            "Projections rendered for one portfolio, keyed by view id. One "
            "entry per requested view, each discriminated by its `view` field."
        ),
        as_of=(
            datetime,
            Field(
                description="Instant the portfolio was read at, fixed per session.",
                examples=["2026-01-15T12:00:00Z"],
            ),
        ),
        portfolio_id=(
            str,
            Field(
                description="The portfolio these projections were rendered from.",
                examples=["current"],
            ),
        ),
        views=(
            _keyed(payload_annotation(projections)),
            Field(description="One rendered projection per requested view id."),
        ),
    )


def catalog_entry(projection: Projection) -> dict[str, Any]:
    """Describe one projection the way `GET /v1/views` answers it (ADR-K D-8).

    Args:
        projection: The registered projection to describe.

    Returns:
        Its id, purpose, endpoints, options schema, actions, component,
        guidance and a rendered example — built in one call, so the documented
        catalog cannot drift from the served one.
    """
    example = dict(projection.example)
    return {
        "id": projection.id,
        "summary": projection.summary,
        "endpoints": list(projection.endpoints),
        "options_schema": projection.options.model_json_schema(),
        # All three are read off the projection rather than from a new
        # Protocol member, so adding a chart still edits no shared file
        # (ADR-K D-15, spec 0022 AC-11) and this catalog names the component
        # the A2UI surface really emits (GGU-53, spec 0023).
        "actions": list(example.get("actions", ())),
        "component": component_of(projection),
        "guidance": guidance_of(projection),
        "example": example,
    }


def response_examples(
    projections: Sequence[Projection], *, as_of: str, portfolio_id: str
) -> dict[str, Any]:
    """Return one OpenAPI example per projection, keyed by view id.

    Args:
        projections: Every registered projection.
        as_of: The instant the example payloads were rendered at.
        portfolio_id: The portfolio id the examples name.

    Returns:
        A mapping usable as an operation's ``content.examples``.
    """
    return {
        projection.id: {
            "summary": projection.summary,
            "value": _example_body(projection, as_of=as_of, portfolio_id=portfolio_id),
        }
        for projection in projections
    }


def _example_body(
    projection: Projection, *, as_of: str, portfolio_id: str
) -> Mapping[str, Any]:
    """Wrap one projection's rendered example in the response envelope."""
    return {
        "as_of": as_of,
        "portfolio_id": portfolio_id,
        "views": {projection.id: dict(projection.example)},
    }


__all__ = [
    "catalog_entry",
    "payload_annotation",
    "response_examples",
    "views_response_model",
]
