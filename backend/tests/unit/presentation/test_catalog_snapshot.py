"""AC-1..AC-7 of spec 0021 — the machine-readable catalog, and its drift check.

This file gates the JSON twin from inside the suite, which is what GGU-53 asks
for: a projection added, renamed or reshaped without `make catalog` turns
`make gate` red here as well as in `catalog-check`. Everything is read from the
registry — no view id, component name or field path is an expectation except
the one case pinning the *verbatim* naming `FinanceCatalog` registers against.
"""

from json import loads
from typing import Any

from app.presentation.catalog_artifacts import ARTIFACTS, FIX_COMMAND, render_all
from app.presentation.catalog_doc import CONTRACT_PATH, contract_document, fields_of
from app.presentation.catalog_json import (
    SNAPSHOT_PATH,
    SNAPSHOT_VERSION,
    component_of,
    snapshot_document,
    snapshot_entry,
)
from app.presentation.registry import REGISTRY
from app.presentation.schema_facts import NONE
from app.presentation.spec import ProjectionSpec
from tests.unit.presentation.conftest import committed


def entries() -> dict[str, Any]:
    """Return the committed snapshot's entries, keyed by view id."""
    views = loads(committed(SNAPSHOT_PATH))["views"]
    return {entry["view"]: entry for entry in views}


def test_snapshot_matches_the_registry() -> None:
    """The gate: regenerate in memory and compare with the committed file."""
    generated = snapshot_document(REGISTRY.all())

    assert committed(SNAPSHOT_PATH) == generated, (
        f"{SNAPSHOT_PATH} is stale — a projection moved. Regenerate it: {FIX_COMMAND}"
    )


def test_every_registered_view_declares_a_client_component() -> None:
    """Every projection reaches the snapshot, with the component it emits."""
    found = entries()

    assert set(found) == {projection.id for projection in REGISTRY.all()}
    for projection in REGISTRY.all():
        component = found[projection.id]["component"]
        assert component == component_of(projection)
        assert isinstance(component, str)
        assert component and component[0].isupper() and component.isalnum()


def test_the_snapshot_names_the_component_the_backend_emits_verbatim() -> None:
    """The client registers against this string, so it is copied, not derived."""
    assert entries()["holdings.allocation.v1"]["component"] == "DonutChart"


def test_the_snapshot_carries_every_field_path_of_the_payload() -> None:
    """The JSON field list is the inventory the Markdown table prints."""
    projection = REGISTRY.get("attribution.waterfall.v1")
    entry = snapshot_entry(projection)

    paths = [field["path"] for field in entry["fields"]]
    assert paths == [row.path for row in fields_of(projection)]
    assert entry["options_schema"] == projection.options.model_json_schema()
    assert entry["payload_type"] == projection.dto.__name__
    assert entry["endpoints"] == list(projection.endpoints)


def test_a_field_that_drives_nothing_reads_null_rather_than_an_em_dash() -> None:
    """A client compares against null, never against a punctuation mark."""
    read_only = entries()["holdings.allocation.v1"]["fields"]

    assert all(field["input"] is None for field in read_only)
    assert not any(NONE in (field["input"], field["state"]) for field in read_only)
    assert [f["path"] for f in entries()["order.ticket.v1"]["fields"] if f["input"]]


def test_the_shipped_example_deserialises_into_its_payload_type() -> None:
    """What the client test asserts, asserted here first: the example is real."""
    for projection in REGISTRY.all():
        entry = entries()[projection.id]
        payload = projection.dto.model_validate(entry["example"])

        assert payload.model_dump(mode="json") == entry["example"]
        assert projection.surface(payload).component == entry["component"]


def test_the_snapshot_is_one_json_document_ending_in_a_single_newline() -> None:
    """A generated file a tool reads, and a file a human diffs."""
    text = committed(SNAPSHOT_PATH)
    document = loads(text)

    assert text.endswith("}\n")
    assert not text.endswith("\n\n")
    assert document["version"] == SNAPSHOT_VERSION
    assert "do not edit by hand" in document["$comment"]
    assert [entry["view"] for entry in document["views"]] == [
        projection.id for projection in REGISTRY.all()
    ]


def test_a_moved_projection_makes_the_snapshot_drift() -> None:
    """The failure path of the gate, without touching a view module."""
    before = REGISTRY.get("holdings.allocation.v1")
    after = ProjectionSpec(
        id=before.id,
        summary="A different sentence entirely.",
        endpoints=before.endpoints,
        options=before.options,
        dto=before.dto,
        render=before.render,
        surface=before.surface,
        fitness=before.fitness,
    )
    stale, current = render_all([before])[1], render_all([after])[1]

    drift = current.drift(stale.generated)

    assert SNAPSHOT_PATH in drift
    assert "A different sentence entirely." in drift
    assert '"digest"' in drift


def test_a_missing_snapshot_is_drift_rather_than_a_pass() -> None:
    """An absent artefact fails the gate instead of silently passing it."""
    drift = render_all(REGISTRY.all())[1].drift("")

    assert drift.startswith(f"--- {SNAPSHOT_PATH}")
    assert '+  "version": 1' in drift


def test_both_catalog_artifacts_come_from_one_render_pass() -> None:
    """One generator, one gate: the Markdown and the JSON are one list."""
    projections = REGISTRY.all()
    rendered = render_all(projections)

    assert [artifact.path for artifact in ARTIFACTS] == [CONTRACT_PATH, SNAPSHOT_PATH]
    assert [item.path for item in rendered] == [CONTRACT_PATH, SNAPSHOT_PATH]
    assert rendered[0].generated == contract_document(projections)
    assert rendered[1].generated == snapshot_document(projections)
    assert rendered[1].drift(rendered[1].generated) == ""
