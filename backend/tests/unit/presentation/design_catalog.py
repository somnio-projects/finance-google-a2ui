"""The design catalog's component names — design's half of the contract.

Split out of ``test_component_names.py`` when that file passed the 150-line
budget; the seam is the one ``tests/catalog.py`` and
``catalog_reach_data.py`` already draw. **Still transcribed exactly once.**
The docstring of the test that reads it explains why a second
transcription is forbidden, and moving the literal to its own module does
not create one: there is one place to change a name, and it is this file.
"""

from typing import Final

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
    # No page of its own and it needs none: the window walk is the SAME
    # component drawing a different quantity (spec `backend/0039`).
    "attribution.window.v1": "AttributionWaterfall",
    # Page now exported: Zone 2 + breadcrumb + badge. Index: `AllocationSummary`.
    "holdings.allocation.v1": "HoldingsSummary",
    # Page now exported and it changed nothing: every rendering agrees.
    "order.ticket.v1": "OrderTicket",
    "order.ticket.v2": "MultiLegOrderTicket",  # v1 holds the name (0031 OD-1)
    # Page now exported: Zone 2 + breadcrumb + badge. Index: `PayoffChart`.
    "payoff.curve.v1": "RiskPayoffChart",
    # Zone 2 + breadcrumb + fragment; the index card says `ComparisonCard`.
    "scenario.comparison.v1": "ScenarioComparison",
    # The one component every rendering already agreed on.
    "taxlots.table.v1": "TaxLotTable",
    # Pages and states in design, projections here; named by us (0026/0028/0032).
    "portfolio.summary.v1": "PortfolioSummary",
    "holdings.positions.v1": "PositionList",
    "activity.timeline.v1": "ActivityTimeline",
    "attribution.driver.v1": "DriverDetail",
}

__all__ = ["DESIGN_CATALOG"]
