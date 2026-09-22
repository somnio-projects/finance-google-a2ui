"""0036 OD-3 — the tool offers the groupings the projection declares.

Two hand-written declarations of one vocabulary: the projection's options
model, which decides what a render intent may carry, and the tool's argument
schema, which decides what the model may ask for. Neither generates the
other. Before this pair existed the tool offered **none** of them, so every
allocation chart drew at its default while the agent narrated whichever
grouping the question implied.
"""

from typing import Any

from app.agent.tools.holdings_grouping import DEFAULT_GROUPING, GROUPINGS
from app.agent.tools.holdings_query import HoldingsSummaryArguments
from app.agent.tools.holdings_schema import MAX_TOP_N, PARAMETERS
from app.presentation.registry import REGISTRY
from app.presentation.views import LOADED

VIEW = "holdings.allocation.v1"


def _declared_groupings() -> list[str]:
    """Read the enum straight out of the projection's own JSON schema.

    Importing ``views`` is what registers them — the package's import list is
    the wiring (ADR-K), so a test that reads the registry has to touch it.
    """
    assert LOADED
    projection = REGISTRY.get(VIEW)
    schema: dict[str, Any] = projection.options.model_json_schema()
    properties: dict[str, Any] = schema["properties"]
    enum: list[str] = properties["group_by"]["enum"]
    return enum


def test_the_tool_offers_every_grouping_the_projection_declares() -> None:
    assert list(GROUPINGS) == _declared_groupings()


def test_the_schema_the_model_reads_offers_the_same_groupings() -> None:
    properties: dict[str, Any] = PARAMETERS["properties"]  # type: ignore[assignment]
    assert properties["group_by"]["enum"] == list(GROUPINGS)


def test_the_default_grouping_is_one_the_projection_accepts() -> None:
    assert DEFAULT_GROUPING in _declared_groupings()


def test_a_call_that_asks_for_a_grouping_puts_it_in_the_intent() -> None:
    """The fix itself: the argument reaches the render intent."""
    options = HoldingsSummaryArguments(group_by="sector")

    assert options.chart_options(4) == {"top_n": 4, "group_by": "sector"}


def test_a_call_that_does_not_ask_gets_the_default() -> None:
    assert HoldingsSummaryArguments().chart_options(4) == {
        "top_n": 4,
        "group_by": DEFAULT_GROUPING,
    }


def test_a_grouping_never_resurrects_a_chart_the_filter_removed() -> None:
    """A grouping is not a reason to draw a chart that does not fit.

    ``chart_options`` returns ``None`` for a filtered or return-ordered
    answer (spec 0011 OD-1), and asking for a grouping must not change that
    — a donut of the whole portfolio under a sentence about three tickers is
    the contradiction that rule exists to prevent.
    """
    filtered = HoldingsSummaryArguments(symbols=("NVDA",), group_by="sector")

    assert filtered.chart_options(1) is None
    assert HoldingsSummaryArguments(group_by="sector").chart_options(0) is None
    assert MAX_TOP_N > 0
