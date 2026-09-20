"""AC-6, AC-8 — the registry rendered into OpenAPI (ADR-K D-4).

The union, the discriminator mapping and the examples are all derived from the
registry here, so this file is what proves a projection cannot reach the
document without them.
"""

from app.presentation.contract import (
    payload_annotation,
    response_examples,
    views_response_model,
)
from app.presentation.registry import REGISTRY


def test_payload_annotation_is_a_discriminated_union_of_every_dto() -> None:
    model = views_response_model(REGISTRY.all(), name="Probe")
    schema = model.model_json_schema()
    union = schema["properties"]["views"]["additionalProperties"]
    assert union["discriminator"]["propertyName"] == "view"
    assert set(union["discriminator"]["mapping"]) == {
        projection.id for projection in REGISTRY.all()
    }
    assert len(union["oneOf"]) == len(REGISTRY.all())
    assert payload_annotation(REGISTRY.all()) is not None


def test_views_response_model_documents_its_envelope() -> None:
    schema = views_response_model(REGISTRY.all(), name="Probe").model_json_schema()
    assert "keyed by view id" in schema["description"]
    assert set(schema["properties"]) == {"as_of", "portfolio_id", "views"}
    for spec in schema["properties"].values():
        assert spec.get("description")


def test_the_documented_model_validates_a_real_render() -> None:
    model = views_response_model(REGISTRY.all(), name="Probe")
    projection = REGISTRY.get("holdings.allocation.v1")
    built = model.model_validate(
        {
            "as_of": "2026-01-15T12:00:00Z",
            "portfolio_id": "current",
            "views": {projection.id: dict(projection.example)},
        }
    )
    assert built.model_dump()["views"][projection.id]["view"] == projection.id


def test_every_example_validates_against_its_own_dto() -> None:
    for projection in REGISTRY.all():
        payload = projection.dto.model_validate(dict(projection.example))
        assert payload.model_dump(mode="json") == dict(projection.example)


def test_response_examples_carry_one_entry_per_projection() -> None:
    examples = response_examples(
        REGISTRY.all(), as_of="2026-01-15T12:00:00Z", portfolio_id="current"
    )
    assert set(examples) == {projection.id for projection in REGISTRY.all()}
    for view_id, example in examples.items():
        assert example["summary"]
        assert example["value"]["portfolio_id"] == "current"
        assert set(example["value"]["views"]) == {view_id}
