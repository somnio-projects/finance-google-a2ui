"""AC-1..AC-4 of spec 0023 — one component name, compared across four places.

The component name is the **single string the Flutter client registers a
widget under**. It is written down in four independent places — the design
catalog, the projection's A2UI adapter, the generated JSON snapshot and the
generated Markdown contract — and until this file existed nothing compared
them. Spec 0021 §1 predicted the consequence and named it: the backend emitted
``WaterfallChart`` and ``DonutChart`` while the design catalog drew the same
two components under different names, and both halves were internally
consistent, so both gates stayed green.

`.claude/rules/backend/testing.md`: **a property that spans two declarations
gets a test comparing them.** This one spans four.
``DESIGN_CATALOG`` below is the design's half, transcribed **once**. It is a
deliberate literal — the one thing in this suite that is not read from the
registry — because the whole point is to compare the backend against something
outside it. Transcribing it in a second place is what this test forbids.
"""

import re
from json import loads
from typing import Final

from app.presentation.catalog_doc import CONTRACT_PATH, contract_document
from app.presentation.catalog_json import SNAPSHOT_PATH, snapshot_document
from app.presentation.contract import catalog_entry
from app.presentation.published import component_of
from app.presentation.registry import REGISTRY
from tests.unit.presentation.conftest import committed

#: The design catalog's own naming; the evidence per page is transcribed in
#: `docs/catalog/design/README.md`, so this literal can be re-verified without
#: the exported HTML that is not in the repository.
#:
#: **How a name was chosen when the design disagreed with itself**, recorded in
#: spec 0023 §3: a component is named by its **own A2UI schema block** (Zone 2
#: of its detail page), which is the literal the client would read off a
#: payload. The gallery badge and the index card do not always agree, and they
#: are decoration. Where no detail page was exported the gallery card was the
#: only declaration and therefore won — a **fallback**, not a tie-break, so it
#: loses the day the page arrives. It did: the last three pages were exported
#: on 2026-09-21 and two adopted names moved (GGU-101, GGU-103; spec 0024).
#: A name seen on *another* component's page is never authoritative — what
#: renamed `HoldingsSummary` is its **own** Zone 2 block (spec 0024).
DESIGN_CATALOG: Final[dict[str, str]] = {
    # Zone 2 + breadcrumb + fragment; badge and index card say `WaterfallChart`.
    "attribution.waterfall.v1": "AttributionWaterfall",
    # Page now exported: Zone 2 + breadcrumb + badge. Index: `AllocationSummary`.
    "holdings.allocation.v1": "HoldingsSummary",
    # Page now exported and it changed nothing: every rendering agrees.
    "order.ticket.v1": "OrderTicket",
    # Page now exported: Zone 2 + breadcrumb + badge. Index: `PayoffChart`.
    "payoff.curve.v1": "RiskPayoffChart",
    # Zone 2 + breadcrumb + fragment; the index card says `ComparisonCard`.
    "scenario.comparison.v1": "ScenarioComparison",
    # The one component every rendering already agreed on.
    "taxlots.table.v1": "TaxLotTable",
    # The Home hero (`Home.dc.html`): a page in design, a projection here so
    # nothing on that screen is computed on the client. Named by us (spec 0026).
    "portfolio.summary.v1": "PortfolioSummary",
}

#: `- **Component:** \`X\`` in a component's own section of the contract.
SECTION_COMPONENT: Final[re.Pattern[str]] = re.compile(
    r"^- \*\*Component:\*\* `([A-Za-z]+)`$", re.MULTILINE
)
#: The `Component` cell of the index table's row for a view.
INDEX_ROW: Final[str] = r"^\| \[`{view}`\]\([^)]*\) \| `([A-Za-z]+)` \|"


def test_the_design_catalog_table_covers_every_registered_view() -> None:
    """Anti-vacuity: a new projection cannot slip past this file unnamed.

    Without this, adding a seventh view and forgetting to name it here would
    leave every comparison below trivially true for the six it does cover.
    """
    assert set(DESIGN_CATALOG) == {projection.id for projection in REGISTRY.all()}


def test_every_projection_emits_the_component_design_named() -> None:
    """AC-1 — the A2UI adapter agrees with the design catalog."""
    emitted = {projection.id: component_of(projection) for projection in REGISTRY.all()}

    assert emitted == DESIGN_CATALOG


def test_the_snapshot_names_the_component_design_named() -> None:
    """AC-2 — the JSON the Flutter client binds to agrees with the design."""
    views = loads(committed(SNAPSHOT_PATH))["views"]
    published = {entry["view"]: entry["component"] for entry in views}

    assert published == DESIGN_CATALOG


def test_the_markdown_contract_names_the_component_design_named() -> None:
    """AC-3 — the document design reads agrees with the design.

    Both renderings of the name are checked: the per-component section and the
    index table. The contract carried **neither** before GGU-53 — a designer
    could not compare the name they had drawn against the name the client
    would register, because the document did not print it.
    """
    document = committed(CONTRACT_PATH)
    sections = SECTION_COMPONENT.findall(document)

    # Anti-vacuity: a regex that matches nothing would make `sorted() ==
    # sorted()` compare two empty lists and pass.
    assert len(sections) == len(DESIGN_CATALOG)
    assert sorted(sections) == sorted(DESIGN_CATALOG.values())
    for view, component in DESIGN_CATALOG.items():
        row = re.search(INDEX_ROW.format(view=re.escape(view)), document, re.MULTILINE)
        assert row is not None, f"{view} has no row in the contract's index table"
        assert row.group(1) == component


def test_the_views_catalog_names_the_component_design_named() -> None:
    """AC-4 — `GET /v1/views` agrees too, so a client need not guess."""
    served = {
        projection.id: catalog_entry(projection)["component"]
        for projection in REGISTRY.all()
    }

    assert served == DESIGN_CATALOG


def test_renaming_a_component_moves_both_generated_artefacts() -> None:
    """The mutation check: the comparison above is not reading a stale file.

    Renaming one adapter must turn **both** artefacts red. If a rendering
    stopped publishing the component, its diff would not move and this file's
    other assertions would keep passing against a document that no longer
    carries the fact they claim to check.
    """
    projection = REGISTRY.get("holdings.allocation.v1")
    original = projection.surface
    renamed = f"Renamed{DESIGN_CATALOG['holdings.allocation.v1']}"

    def surface_with_another_name(payload: object) -> object:
        return original(payload).model_copy(update={"component": renamed})

    object.__setattr__(projection, "surface", surface_with_another_name)
    try:
        assert renamed in snapshot_document(REGISTRY.all())
        assert renamed in contract_document(REGISTRY.all())
    finally:
        object.__setattr__(projection, "surface", original)

    assert renamed not in committed(SNAPSHOT_PATH)
    assert renamed not in committed(CONTRACT_PATH)
