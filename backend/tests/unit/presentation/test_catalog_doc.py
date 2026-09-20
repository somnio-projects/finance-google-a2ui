"""AC-5, AC-6, AC-7 — the frozen contract, and the check that keeps it frozen.

Three things are proven here. The document covers **every** registered
projection and is driven by the registry rather than by a list (AC-5). The
digest is a fingerprint of the whole promise, so a change anywhere inside a
`v1` moves it (AC-6). And the staleness check **bites**: a projection registered
after the document was rendered makes ``contract_drift`` non-empty and names
the change (AC-7).
"""

from app.presentation.catalog_artifacts import FIX_COMMAND
from app.presentation.catalog_doc import (
    CONTRACT_PATH,
    DIGEST_LENGTH,
    contract_document,
    contract_drift,
    digest,
    fields_of,
)
from app.presentation.registry import REGISTRY
from app.presentation.spec import ProjectionSpec
from tests.unit.presentation.conftest import committed


def test_contract_matches_the_registry() -> None:
    """The twin of the snapshot's gate: the committed Markdown is current.

    Without it the double gate is asymmetric — the JSON is checked from inside
    the suite and the Markdown only by the script, so a generator that stopped
    reporting one artefact would let a stale `CONTRACT.md` through every check.
    """
    generated = contract_document(REGISTRY.all())

    assert committed(CONTRACT_PATH) == generated, (
        f"{CONTRACT_PATH} is stale — a projection moved. Regenerate it: {FIX_COMMAND}"
    )


def test_the_document_covers_every_registered_projection() -> None:
    projections = REGISTRY.all()
    document = contract_document(projections)

    assert document.startswith("# Frozen catalog contract")
    assert document.endswith("\n")
    assert not document.endswith("\n\n")
    for projection in projections:
        assert f"## `{projection.id}`" in document
        assert projection.summary in document
        assert f"`{digest(projection)}`" in document


def test_the_document_prints_the_inventory_and_the_example_of_each_projection() -> None:
    projection = REGISTRY.get("attribution.waterfall.v1")
    document = contract_document([projection])

    for row in fields_of(projection):
        assert f"| `{row.path}` |" in document
    assert "| Field | Type / format | Presence | Binding | State | Input |" in document
    assert '"view": "attribution.waterfall.v1"' in document
    for endpoint in projection.endpoints:
        assert f"`{endpoint}`" in document


def test_a_read_only_projection_says_so_rather_than_leaving_the_cell_blank() -> None:
    document = contract_document([REGISTRY.get("holdings.allocation.v1")])

    assert "**Editable fields:** read-only" in document


def test_the_digest_is_short_stable_and_distinct_per_projection() -> None:
    digests = {projection.id: digest(projection) for projection in REGISTRY.all()}

    assert all(len(value) == DIGEST_LENGTH for value in digests.values())
    assert len(set(digests.values())) == len(digests)
    assert digests == {
        projection.id: digest(projection) for projection in REGISTRY.all()
    }


def test_the_digest_moves_when_anything_inside_a_frozen_v1_moves() -> None:
    projection = REGISTRY.get("holdings.allocation.v1")
    renamed = ProjectionSpec(
        id=projection.id,
        summary="A different sentence entirely.",
        endpoints=projection.endpoints,
        options=projection.options,
        dto=projection.dto,
        render=projection.render,
        surface=projection.surface,
        fitness=projection.fitness,
    )

    assert digest(renamed) != digest(projection)


def test_an_unchanged_document_reports_no_drift() -> None:
    document = contract_document(REGISTRY.all())

    assert contract_drift(checked_in=document, generated=document) == ""


def test_the_check_bites_when_a_projection_changes_after_the_document_was_written() -> (
    None
):
    """The gate's own failure path: render, move the projection, re-render."""
    before = REGISTRY.get("holdings.allocation.v1")
    stale = contract_document([before])
    after = ProjectionSpec(
        id=before.id,
        summary=before.summary,
        endpoints=("GET /v1/portfolios/{portfolio_id}/views",),
        options=before.options,
        dto=before.dto,
        render=before.render,
        surface=before.surface,
        fitness=before.fitness,
    )

    drift = contract_drift(checked_in=stale, generated=contract_document([after]))

    assert CONTRACT_PATH in drift
    # The dropped endpoint leaves on a `-` line, and the digest moves with it.
    assert "-- **Served by:**" in drift
    assert "POST /v1/view-renders" in drift
    assert f"`{digest(before)}`" not in contract_document([after])


def test_a_missing_document_is_drift_rather_than_a_pass() -> None:
    generated = contract_document(REGISTRY.all())

    drift = contract_drift(checked_in="", generated=generated)

    assert drift.startswith(f"--- {CONTRACT_PATH}")
    assert "+# Frozen catalog contract" in drift
