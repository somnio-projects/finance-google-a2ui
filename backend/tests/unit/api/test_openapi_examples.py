"""Every operation that returns a body must show the client what it looks like.

`.claude/rules/backend/api-design.md` §2 requires "at least one request example
and one response example" on every operation. **Nothing checked it** — the
contract test asserts summary, description, operation id, tags, responses and
parameters, and says nothing about examples. The rule was enforced by hope.

One operation had actually shipped without one, and it was the worst possible
one: `POST /` — the A2A surface, whose body is a JSON-RPC envelope and whose
answer is an event stream, so FastAPI derives *no* schema from the signature.
It was the route a client author has least to go on and the least documented.

The first version of this check reported three, because it looked for examples
on the response and on a `$ref`-ed model only. A list endpoint generates an
inline `{"type": "array", "items": {"$ref": ...}}`, and the item model's
examples hang off the *item* — so two list endpoints that were properly
documented looked bare. Hence `_has_example` resolves through the array, and
`test_a_response_whose_schema_is_an_unexampled_array_is_caught` pins both
directions: a guard that over-reports teaches people to ignore it.

Split from `test_openapi_contract.py` under the 150-line budget, the same way
`test_openapi_projections.py` was.
"""

from typing import Any

from fastapi import FastAPI

#: Routes FastAPI generates for the documentation itself.
GENERATED = {"/openapi.json", "/docs", "/docs/oauth2-redirect", "/redoc"}

#: A 204 carries no body by contract, so an example would be a lie, not a gap.
NO_BODY = {"204", "304"}


def _resolve(schema: dict[str, Any], document: dict[str, Any]) -> dict[str, Any]:
    """Follow a local ``$ref`` into ``components.schemas``, once."""
    ref = schema.get("$ref", "")
    if not ref.startswith("#/components/schemas/"):
        return schema
    name = ref.rsplit("/", 1)[-1]
    return document.get("components", {}).get("schemas", {}).get(name, {})


def _has_example(media: dict[str, Any], document: dict[str, Any]) -> bool:
    """Return whether a media-type object shows a concrete value anywhere.

    Checks the three places FastAPI and pydantic put one: on the response
    itself, on the referenced model, and — the case that was missing — on the
    *items* of an inline array, which is what a list endpoint generates.
    """
    if media.get("example") or media.get("examples"):
        return True
    schema = media.get("schema") or {}
    resolved = _resolve(schema, document)
    if resolved.get("example") or resolved.get("examples"):
        return True
    if resolved.get("type") == "array":
        item = _resolve(resolved.get("items") or {}, document)
        return bool(item.get("example") or item.get("examples"))
    return False


def test_every_successful_response_with_a_body_carries_an_example(
    app: FastAPI,
) -> None:
    document = app.openapi()
    undocumented: list[str] = []

    for path, item in document["paths"].items():
        if path in GENERATED:
            continue
        for method, operation in item.items():
            for code, response in operation.get("responses", {}).items():
                if not code.isdigit() or not code.startswith("2") or code in NO_BODY:
                    continue
                content = response.get("content") or {}
                if not content:
                    continue  # a 2xx that genuinely returns nothing
                if not any(_has_example(media, document) for media in content.values()):
                    undocumented.append(f"{method.upper()} {path} -> {code}")

    assert not undocumented, (
        "these operations answer with a body that the document never shows:\n  "
        + "\n  ".join(undocumented)
        + "\nThe OpenAPI document is how the client is written; an unexampled "
        "response is one the client author has to guess at."
    )


def test_a_response_whose_schema_is_an_unexampled_array_is_caught() -> None:
    """The guard must bite on the exact shape that slipped through.

    An inline array of a `$ref` is what a list endpoint generates, and it is
    the case a `$ref`-only check calls documented. Asserted directly so the
    rule survives a refactor of `_has_example`.
    """
    flag: dict[str, Any] = {"properties": {}}
    document: dict[str, Any] = {"components": {"schemas": {"Flag": flag}}}
    items = {"$ref": "#/components/schemas/Flag"}
    media: dict[str, Any] = {"schema": {"type": "array", "items": items}}

    assert _has_example(media, document) is False

    flag["examples"] = [{"key": "x"}]
    assert _has_example(media, document) is True
