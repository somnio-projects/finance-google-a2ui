"""Spec 0034 — the catalog serves what the developer gallery binds.

Two facts the snapshot has carried since GGU-53 now reach `GET /v1/views` as
well: the field inventory and the prompt fragment. Both are *renderings* of
facts the entry already carried, so every assertion here compares them with
the thing they render from rather than with a literal.
"""

from app.presentation.catalog_doc import DERIVED_KEYS, digest
from app.presentation.catalog_json import snapshot_entry
from app.presentation.contract import catalog_entry
from app.presentation.prompt import prompt_fragment, view_fragment
from app.presentation.published import field_rows, inventory_of
from app.presentation.registry import REGISTRY
from app.presentation.schema_facts import NONE
from app.schemas.view_catalog import ViewDescriptor
from app.schemas.view_field import FieldDescriptor


def test_the_catalog_entry_serves_the_rows_the_snapshot_holds() -> None:
    """One inventory, two artefacts: the served rows are the snapshot's."""
    for projection in REGISTRY.all():
        entry = catalog_entry(projection)

        assert entry["fields"] == snapshot_entry(projection)["fields"]
        assert [row["path"] for row in entry["fields"]] == [
            field.path for field in inventory_of(projection)
        ]


def test_a_row_reads_null_where_the_table_prints_a_dash() -> None:
    """A client compares against null, never against a punctuation mark."""
    rows = field_rows(REGISTRY.get("holdings.allocation.v1"))
    by_path = {row["path"]: row for row in rows}

    assert NONE not in {row["state"] for row in rows}
    assert NONE not in {row["input"] for row in rows}
    assert by_path["title"]["state"] is None
    assert by_path["title"]["input"] is None
    assert by_path["group_by"]["state"] == "variant"
    assert by_path["group_by"]["input"] is not None


def test_the_entry_carries_the_lines_the_prompt_teaches() -> None:
    """Zone 3 shows what the model reads, so it is the same text."""
    whole = prompt_fragment(REGISTRY.all())
    for projection in REGISTRY.all():
        fragment = catalog_entry(projection)["prompt"]

        assert fragment == view_fragment(projection)
        assert fragment in whole
        assert fragment.startswith(f"- {projection.id} — {projection.summary}")
        assert snapshot_entry(projection)["prompt"] == fragment


def test_the_fragment_carries_the_pair_only_where_design_wrote_one() -> None:
    designed = REGISTRY.get("attribution.waterfall.v1")
    undesigned = REGISTRY.get("order.ticket.v1")

    assert "  use when: " in view_fragment(designed)
    assert "  use when: " not in view_fragment(undesigned)
    assert view_fragment(undesigned).count("\n") == 1


def test_the_digest_ignores_the_derived_renderings_and_they_exist() -> None:
    """A wording change in a rendering must not move a frozen `v1` digest."""
    for projection in REGISTRY.all():
        entry = catalog_entry(projection)

        assert set(DERIVED_KEYS) <= set(entry)
        assert len(digest(projection)) == 12


def test_the_published_descriptor_matches_the_served_row() -> None:
    """Two declarations of one row — `schemas/` may not import this layer."""
    for projection in REGISTRY.all():
        entry = catalog_entry(projection)
        described = ViewDescriptor.model_validate(entry)

        assert [row.model_dump() for row in described.fields] == entry["fields"]
        assert described.prompt == entry["prompt"]
    assert set(FieldDescriptor.model_fields) == set(field_rows(REGISTRY.all()[0])[0])
