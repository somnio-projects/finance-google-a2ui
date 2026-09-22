"""Where an example may live, and what must carry a description (spec 0038).

`api.openapi_shapes` answers shape questions about the document dictionary.
They are small and pure, so each is provoked with the smallest document that
can provoke it.
"""

from app.api.openapi_shapes import (
    Finding,
    declared_tags,
    has_example,
    resolve,
    schema_findings,
    summarise,
)

DOCUMENT = {
    "components": {
        "schemas": {
            "Thing": {"description": "A thing.", "example": {"id": 1}},
            "Bare": {"properties": {"id": {}}},
            "Optional": {
                "description": "Has an optional.",
                "properties": {"id": {"anyOf": [{"description": "The id."}, {}]}},
            },
        }
    },
    "tags": [{"name": "things", "description": "Things."}, {"name": "bare"}],
}


def test_a_finding_reads_as_one_line() -> None:
    assert str(Finding("GET /v1/me", "tag", "no tag")) == "GET /v1/me: tag — no tag"


def test_a_schema_without_a_reference_resolves_to_itself() -> None:
    schema = {"type": "string"}
    assert resolve(schema, DOCUMENT) is schema


def test_a_local_reference_resolves_into_components() -> None:
    ref = {"$ref": "#/components/schemas/Thing"}
    assert resolve(ref, DOCUMENT)["description"] == "A thing."


def test_an_unknown_reference_resolves_to_nothing() -> None:
    assert resolve({"$ref": "#/components/schemas/Missing"}, DOCUMENT) == {}


def test_an_example_on_the_media_type_counts() -> None:
    assert has_example({"example": {"id": 1}}, DOCUMENT)


def test_an_example_on_the_referenced_model_counts() -> None:
    media = {"schema": {"$ref": "#/components/schemas/Thing"}}
    assert has_example(media, DOCUMENT)


def test_an_example_on_the_items_of_a_list_counts() -> None:
    media = {
        "schema": {
            "type": "array",
            "items": {"$ref": "#/components/schemas/Thing"},
        }
    }
    assert has_example(media, DOCUMENT)


def test_a_list_of_something_unexampled_does_not_count() -> None:
    media = {"schema": {"type": "array", "items": {"type": "string"}}}
    assert not has_example(media, DOCUMENT)


def test_a_media_type_with_nothing_concrete_does_not_count() -> None:
    assert not has_example({"schema": {"type": "string"}}, DOCUMENT)


def test_an_undescribed_schema_and_property_are_both_reported() -> None:
    details = [finding.detail for finding in schema_findings(DOCUMENT)]
    assert "has no description (docstring)" in details
    assert "property 'id' has no description" in details


def test_a_description_on_one_anyof_option_is_enough() -> None:
    reported = [
        finding for finding in schema_findings(DOCUMENT) if "Optional" in finding.where
    ]
    assert reported == []


def test_a_document_with_no_components_reports_nothing() -> None:
    assert list(schema_findings({})) == []


def test_tags_are_read_with_their_descriptions() -> None:
    assert declared_tags(DOCUMENT) == {"things": "Things.", "bare": ""}


def test_findings_are_counted_by_kind_in_order() -> None:
    findings = [
        Finding("a", "tag", "one"),
        Finding("b", "schema", "two"),
        Finding("c", "tag", "three"),
    ]
    assert summarise(findings) == "  schema: 1\n  tag: 2"
