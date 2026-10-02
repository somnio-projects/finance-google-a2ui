"""ADR-M D-4 — which views become one surface, and in what order (AC-4).

The composer is fed views one at a time, exactly as a turn yields them, and
the property under test is twofold: a payoff curve right after a ticket joins
the ticket's surface, and **nothing is ever reordered** — a held ticket is
released before whatever followed it.
"""

import pytest

from app.presentation.a2ui_v1.composition import (
    accepts,
    allowed_children,
    label,
    nests_only,
)
from app.presentation.a2ui_v1.surfaces import (
    CONTAINERS,
    RenderedView,
    SurfaceComposer,
    surface_message,
)


def _view(component: str, view: str, index: int) -> RenderedView:
    return RenderedView(
        index=index, component=component, view=view, options={}, payload={"view": view}
    )


TICKET = _view("MultiLegOrderTicket", "order.ticket.v2", 0)
PAYOFF = _view("RiskPayoffChart", "payoff.curve.v1", 1)
SUMMARY = _view("PortfolioSummary", "portfolio.summary.v1", 1)
WATERFALL = _view("AttributionWaterfall", "attribution.window.v1", 0)
DRIVER = _view("DriverDetail", "attribution.driver.v1", 1)


def _groups(*views: RenderedView) -> list[tuple[RenderedView, ...]]:
    composer = SurfaceComposer()
    groups = [group for view in views for group in composer.add(view)]
    return [*groups, *composer.flush()]


def test_a_ticket_then_its_payoff_is_one_surface() -> None:
    assert _groups(TICKET, PAYOFF) == [(TICKET, PAYOFF)]


def test_a_held_ticket_is_released_before_the_next_view() -> None:
    assert _groups(TICKET, SUMMARY) == [(TICKET,), (SUMMARY,)]


def test_a_ticket_at_the_end_of_the_turn_is_flushed() -> None:
    assert _groups(SUMMARY, TICKET) == [(SUMMARY,), (TICKET,)]


def test_a_payoff_with_no_ticket_before_it_is_never_drawn() -> None:
    assert _groups(PAYOFF) == []


def test_a_ticket_holds_one_payoff_and_drops_a_second() -> None:
    assert _groups(TICKET, PAYOFF, PAYOFF) == [(TICKET, PAYOFF)]


def test_a_waterfall_is_never_held_back_for_a_driver_detail() -> None:
    composer = SurfaceComposer()

    assert composer.add(WATERFALL) == [(WATERFALL,)]
    assert composer.add(DRIVER) == [(DRIVER,)]
    assert composer.flush() == []


def test_only_the_tickets_are_containers() -> None:
    assert CONTAINERS == {"OrderTicket", "MultiLegOrderTicket"}


@pytest.mark.parametrize(
    ("parent", "child", "expected"),
    [
        ("OrderTicket", "RiskPayoffChart", True),
        ("AttributionWaterfall", "DriverDetail", False),
        ("PortfolioSummary", "RiskPayoffChart", False),
    ],
    ids=["ticket-takes-payoff", "driver-may-stand-alone", "summary-is-a-leaf"],
)
def test_accepts_composes_only_what_cannot_stand_alone(
    parent: str, child: str, expected: bool
) -> None:
    assert accepts(parent, child) is expected


def test_nests_only_and_children_follow_the_parents_table() -> None:
    assert nests_only("RiskPayoffChart")
    assert not nests_only("DriverDetail")
    catalog = ["OrderTicket", "RiskPayoffChart", "PortfolioSummary"]
    assert allowed_children("OrderTicket", catalog) == ("RiskPayoffChart",)
    assert allowed_children("PortfolioSummary", catalog) == ()


@pytest.mark.parametrize(
    ("component", "words"),
    [
        ("MultiLegOrderTicket", "Multi leg order ticket"),
        ("PortfolioSummary", "Portfolio summary"),
        ("Section", "Section"),
    ],
    ids=["four-words", "two-words", "one-word"],
)
def test_label_reads_the_component_name_as_words(component: str, words: str) -> None:
    assert label(component) == words


def test_a_composed_surface_names_its_child_and_binds_it_apart() -> None:
    message = surface_message("task", (TICKET, PAYOFF))["createSurface"]

    assert message["surfaceId"] == "task-0"
    assert message["components"][0]["children"] == ["payoff"]
    assert message["components"][1]["data"] == {"path": "/payoff"}
    assert sorted(message["dataModel"]) == ["payoff", "root"]
