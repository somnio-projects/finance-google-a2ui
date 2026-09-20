"""The examples half of the OpenAPI contract (`api-design.md` §2).

`test_openapi_contract.py` enforces summaries, ids, tags, statuses and
descriptions; `test_openapi_projections.py` enforces the projection payloads.
Between them, **examples were never checked** — the rule asked for "at least
one request example and one response example, using realistic finance values"
and nothing failed when an operation shipped without either.

That is the same shape of gap this project has been bitten by before: a rule
that reads as enforced, is not, and quietly stops being true. These tests
close it. An operation that genuinely cannot carry an example is named in
``WITHOUT_EXAMPLES`` below — a visible diff, never a silent hole.
"""

from typing import Any

from fastapi import FastAPI

from tests.unit.api.test_openapi_contract import GENERATED

#: Operations with nothing meaningful to exemplify, each with its reason.
#: Adding a path here is a documentation decision and needs a line saying why.
WITHOUT_EXAMPLES: dict[tuple[str, str], str] = {
    # The A2A surface is JSON-RPC: one envelope for many methods, answering
    # either an event stream or an error object. FastAPI cannot type either
    # side, so the shapes are documented in the description and in
    # `app/schemas/a2a.py`, whose fields all carry their own examples.
    ("post", "/"): "JSON-RPC envelope; neither side has a single schema",
}


def _operations(app: FastAPI) -> list[tuple[str, str, dict[str, Any]]]:
    """Return every documented operation, excluding FastAPI's own routes."""
    schema = app.openapi()
    return [
        (path, method, operation)
        for path, item in schema["paths"].items()
        if path not in GENERATED
        for method, operation in item.items()
        if (method, path) not in WITHOUT_EXAMPLES
    ]


def _has_example(node: dict[str, Any]) -> bool:
    """Return True when a schema or media node carries an example of any form."""
    return node.get("example") is not None or bool(node.get("examples"))


def _exemplified(media: dict[str, Any], schemas: dict[str, Any]) -> bool:
    """Return True when this media type shows an example, however it was given.

    The rule accepts either `openapi_examples` on the operation — which lands
    on the media type — or `json_schema_extra`, which lands on the component
    schema. So a `$ref` (and an array's `items`) is followed rather than read
    as "no example", which would have made the rule unsatisfiable the
    documented way.
    """
    if _has_example(media):
        return True
    node = media.get("schema") or {}
    # `anyOf`/`oneOf` are deliberately not followed: every union this service
    # serves carries an inline example on the operation, and "one member has an
    # example" would not prove the union is documented. A future union that
    # relies only on per-member `json_schema_extra` will fail here — correctly,
    # but for a reason this comment is the explanation of.
    for _ in range(4):  # ref → array → ref is the deepest shape we produce
        if _has_example(node):
            return True
        if "$ref" in node:
            node = schemas.get(node["$ref"].rsplit("/", 1)[-1], {})
        elif "items" in node:
            node = node["items"]
        else:
            return False
    return False


def _success_responses(operation: dict[str, Any]) -> list[dict[str, Any]]:
    """Return the operation's 2xx responses that carry a body."""
    return [
        response
        for status, response in operation["responses"].items()
        if status.isdigit() and 200 <= int(status) < 300 and response.get("content")
    ]


def _component_schemas(app: FastAPI) -> dict[str, Any]:
    """Return the document's component schemas, for resolving `$ref`s."""
    return app.openapi()["components"]["schemas"]


def test_every_operation_documents_a_response_example(app: FastAPI) -> None:
    """A client generator without an example produces untestable stubs.

    Every 2xx response that carries a body must show one — either inline on
    the operation, or on the schema through `json_schema_extra` / field-level
    `examples`, which is what FastAPI renders for a `response_model`.
    """
    schemas = _component_schemas(app)
    checked = 0
    for path, method, operation in _operations(app):
        where = f"{method.upper()} {path}"
        responses = _success_responses(operation)
        if not responses:
            # A 204 answers with no body, so there is nothing to exemplify.
            # Insisting otherwise would push a fake example onto a DELETE.
            assert "204" in operation["responses"], (
                f"{where} documents no success response with a body"
            )
            continue
        checked += 1
        for response in responses:
            assert any(
                _exemplified(media, schemas) for media in response["content"].values()
            ), f"{where} has a success response without an example"
    assert checked, "no operation with a response body was checked"


def test_every_operation_with_a_body_documents_a_request_example(
    app: FastAPI,
) -> None:
    """The request half of the same rule: show a caller what to send."""
    schemas = _component_schemas(app)
    checked = 0
    for path, method, operation in _operations(app):
        body = operation.get("requestBody")
        if body is None:
            continue
        checked += 1
        assert any(
            _exemplified(media, schemas) for media in body["content"].values()
        ), f"{method.upper()} {path} accepts a body with no request example"
    assert checked, "no operation with a request body was checked"


def test_the_exemption_list_only_names_routes_that_exist(app: FastAPI) -> None:
    """An exemption for a route that is gone is a hole waiting to be reused."""
    paths = app.openapi()["paths"]
    for method, path in WITHOUT_EXAMPLES:
        assert path in paths, f"{path} is exempted but no longer exists"
        assert method in paths[path], f"{method.upper()} {path} is exempted but absent"
