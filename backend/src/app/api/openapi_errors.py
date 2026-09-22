"""Make every documented error response say what the service really answers.

Split from `api.openapi_document` under the 150-line budget. Two corrections,
both of them about a media type (spec 0035 OD-3):

* ``problem_responses`` passes ``model=ProblemDetails`` so the schema reaches
  ``components``, and FastAPI attaches that schema to *its* default media type.
  The schema and the example therefore landed on different media types — and
  `api.errors` only ever answers ``application/problem+json``, so a client was
  offered one shape it would never receive and another with nothing to
  generate from.
* FastAPI adds its own ``HTTPValidationError`` 422 to every operation that has
  any parameter at all, including the optional ``Authorization`` header, which
  cannot fail. This service never answers that shape.

`api.openapi_statuses.problem_shape_findings` asserts the result, so a future
change that reintroduces either is a failed gate rather than a surprise in a
generated client.
"""

import json
from collections.abc import Sequence
from typing import Any, Final

from app.api.openapi_shapes import REF_PREFIX
from app.api.openapi_statuses import PLAIN_JSON, PROBLEM_JSON
from app.api.route_facts import RouteFacts

#: FastAPI's 422 envelope, unreferenced once every 422 is a problem document.
VALIDATION_SCHEMAS: Final[tuple[str, ...]] = ("HTTPValidationError", "ValidationError")


def _fold_problem(entry: dict[str, Any]) -> None:
    """Leave one media type on an error: the problem document, with its schema."""
    content: dict[str, Any] = entry["content"]
    problem: dict[str, Any] = content[PROBLEM_JSON]
    plain = content.pop(PLAIN_JSON, None)
    if plain is not None and "schema" not in problem:
        problem["schema"] = plain["schema"]
    entry["content"] = {PROBLEM_JSON: problem}


def correct_error_responses(
    document: dict[str, Any], facts: Sequence[RouteFacts]
) -> None:
    """Fold every problem response, and drop a 422 no controller declared.

    A 422 carrying a problem document was declared by the controller. A 422 of
    any other shape is FastAPI's boilerplate and goes entirely — and if the
    route really can fail validation, `api.openapi_audit` then reports the
    missing status, so the two checks answer for each other.

    Args:
        document: The document, modified in place.
        facts: ``route_facts(app)`` for the same application.
    """
    for fact in facts:
        responses: dict[str, Any] = fact.operation(document)["responses"]
        for code, entry in list(responses.items()):
            if PROBLEM_JSON in (entry.get("content") or {}):
                _fold_problem(entry)
            elif code == "422":
                del responses[code]


def drop_validation_schemas(document: dict[str, Any]) -> None:
    """Remove FastAPI's 422 envelope schemas once nothing references them.

    Both go or neither does: ``HTTPValidationError`` is the only thing that
    references ``ValidationError``, so removing them as a pair and restoring
    the pair is the only test that does not depend on the order.

    Args:
        document: The document, modified in place.
    """
    schemas: dict[str, Any] = document.get("components", {}).get("schemas", {})
    removed = {
        name: schemas.pop(name) for name in VALIDATION_SCHEMAS if name in schemas
    }
    remaining = json.dumps(document)
    if any(f"{REF_PREFIX}{name}" in remaining for name in removed):
        schemas.update(removed)


__all__ = ["VALIDATION_SCHEMAS", "correct_error_responses", "drop_validation_schemas"]
