"""Spec 0013 §3 — how a simulated sale reads once it leaves the domain."""

from decimal import Decimal

from app.agent.tools import sale_rows
from tests.unit.agent.tools.sale_fixtures import free_sale


def test_a_sale_of_something_that_cost_nothing_has_no_percentage() -> None:
    """OD-6 — the dollar figure still stands; the ratio is absent, not zero."""
    summary = sale_rows.summary(free_sale(), method="FIFO")

    assert summary["realizedPlPctDisplay"] is None
    assert summary["realizedPlDisplay"] == "+$500.00"
    assert summary["costBasisDisplay"] == "$0.00"


def test_the_method_the_caller_asked_for_travels_with_the_answer() -> None:
    """OD-9 — a payload read on its own still says which comparison it is."""
    assert sale_rows.summary(free_sale(), method="HIFO")["lotMethod"] == "HIFO"


def test_a_consumed_lot_names_its_lot_its_day_and_its_term() -> None:
    """The three fields the tax-lot table keys off are not figures."""
    row = sale_rows.lot_row(free_sale().consumed[0])

    assert row["lotId"] == "lot-air-01"
    assert row["term"] == "short"
    assert row["fullySold"] is True
    assert row["acquiredOnDisplay"] == "2026-09-18"


def test_an_emptied_position_reads_as_empty_rather_than_as_missing() -> None:
    """A sold-out position is four zeros, not an absent block."""
    left = sale_rows.remaining(free_sale())

    assert left == {
        "count": 0,
        "quantityDisplay": "0",
        "costBasisDisplay": "$0.00",
        "marketValueDisplay": "$0.00",
    }


def test_an_over_sell_reports_both_quantities_already_formatted() -> None:
    """OD-3 — the model copies the shortfall; it never works one out."""
    refusal = sale_rows.too_small(
        symbol="NVDA", requested=Decimal("1.5"), held=Decimal("0.6")
    )

    assert refusal == {
        "error": "position-too-small",
        "symbol": "NVDA",
        "requestedDisplay": "1.5",
        "heldDisplay": "0.6",
    }
