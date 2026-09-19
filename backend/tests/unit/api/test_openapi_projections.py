"""AC-12 — the gate a projection cannot reach the document without.

Spec 0005 extends the OpenAPI contract test so that a registered projection
without an OpenAPI example, without an options schema, or without its
discriminator literal fails here rather than at a client's runtime. These
assertions read the **registry**, so they cover whatever is registered today
and whatever is added tomorrow, without being edited (ADR-K D-14, D-15).
"""

from typing import Any

from fastapi import FastAPI

from app.presentation.registry import REGISTRY

#: The operation that serves every projection.
VIEWS_PATH = "/v1/portfolios/{portfolio_id}/views"


def _views_operation(app: FastAPI) -> dict[str, Any]:
    return app.openapi()["paths"][VIEWS_PATH]["get"]


def test_every_projection_has_an_openapi_example(app: FastAPI) -> None:
    """A projection reaches the document with a real example, or fails here.

    Spec 0005 AC-12 — the example is rendered from the registry, so an empty
    or missing one means a projection was registered without a working render.
    """
    content = _views_operation(app)["responses"]["200"]["content"]
    examples = content["application/json"]["examples"]
    for projection in REGISTRY.all():
        assert projection.id in examples, f"{projection.id} has no OpenAPI example"
        example = examples[projection.id]
        assert example["summary"], f"{projection.id} has an unlabelled example"
        payload = example["value"]["views"][projection.id]
        assert payload, f"{projection.id} has an empty example payload"
        assert projection.dto.model_validate(payload)


def test_every_projection_dto_declares_its_discriminator_literal(app: FastAPI) -> None:
    """Every payload carries `view: Literal[<its id>]` (ADR-K D-4)."""
    schemas = app.openapi()["components"]["schemas"]
    union = schemas["PortfolioViews"]["properties"]["views"]["additionalProperties"]
    assert union["discriminator"]["propertyName"] == "view"
    mapping = union["discriminator"]["mapping"]
    for projection in REGISTRY.all():
        assert projection.id in mapping, f"{projection.id} is not in the union"
        name = mapping[projection.id].rsplit("/", 1)[-1]
        assert schemas[name]["properties"]["view"]["const"] == projection.id
        field = projection.dto.model_fields["view"]
        assert field.default == projection.id


def test_every_projection_publishes_an_options_schema(app: FastAPI) -> None:
    """The catalog cannot describe a projection whose options are undeclared."""
    for projection in REGISTRY.all():
        schema = projection.options.model_json_schema()
        assert schema.get("properties"), f"{projection.id} declares no options"
        for name, spec in schema["properties"].items():
            described = spec.get("description") or any(
                option.get("description") for option in spec.get("anyOf", [])
            )
            assert described, f"{projection.id}.{name} has no description"
            assert "default" in spec, f"{projection.id}.{name} has no default"


def test_the_views_operation_documents_its_repeated_parameter(app: FastAPI) -> None:
    """`view` is repeatable and capped, and every option is documented."""
    parameters = {p["name"]: p for p in _views_operation(app)["parameters"]}
    assert parameters["view"]["schema"]["type"] == "array"
    assert parameters["view"]["schema"]["maxItems"] >= 1
    assert all(parameter["description"] for parameter in parameters.values())
