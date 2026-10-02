"""Spec 0051 — the declared rates are visible, bounded, and actually applied."""

from decimal import Decimal

import pytest
from pydantic import ValidationError

from app.domain.portfolio import Portfolio
from app.domain.scenario_tax import MAX_RATE
from app.presentation.views.scenario_comparison import (
    ScenarioComparisonOptions,
    ScenarioComparisonPayload,
    render,
)


def test_the_card_prints_the_rates_it_costed_with(portfolio: Portfolio) -> None:
    """AC-1/GGU-134 — the assumption is on the surface or it is invented.

    Composed from the options this render used, not from a constant that
    could drift from them: a note claiming 35 % beside a figure costed at
    10 % is the defect the whole ticket is about.
    """
    payload = render(
        portfolio,
        ScenarioComparisonOptions(short_term_rate="0.1", long_term_rate="0.05"),
    )
    rates = next(note for note in payload.notes if "estimated at" in note.text)

    assert "10.00%" in rates.text
    assert "5.00%" in rates.text
    assert "35" not in rates.text


def _tax(payload: ScenarioComparisonPayload) -> Decimal:
    """What the whole card estimates, across every column."""
    return sum((column.est_tax.amount for column in payload.columns), Decimal(0))


def _at(*, short: str = "0.35", long_term: str = "0.15") -> ScenarioComparisonOptions:
    """Options at the named rates, spelled out so the types stay checked."""
    return ScenarioComparisonOptions(short_term_rate=short, long_term_rate=long_term)


def test_changing_the_short_rate_changes_the_figure(portfolio: Portfolio) -> None:
    """AC-1 — the option is wired to the arithmetic, not only to the prose.

    Asserted over the **sum across columns**, not over `columns[0]`. The first
    draft read FIFO's tax and failed: on the seeded portfolio FIFO consumes a
    single long-term lot, so its short-term part is zero and a short rate
    cannot move it. A per-column assertion here would test which lots the seed
    happens to hold.
    """
    assert _tax(render(portfolio, _at(short="0.5"))) > _tax(
        render(portfolio, _at(short="0.1"))
    )


def test_changing_the_long_rate_changes_the_figure(portfolio: Portfolio) -> None:
    """AC-1 — the same, for the other half."""
    assert _tax(render(portfolio, _at(long_term="0.5"))) > _tax(
        render(portfolio, _at(long_term="0.1"))
    )


def test_a_zero_rate_is_allowed_and_means_no_tax(portfolio: Portfolio) -> None:
    """AC-1 — "show me pre-tax" stays expressible; it was the old behaviour."""
    payload = render(
        portfolio,
        ScenarioComparisonOptions(short_term_rate="0", long_term_rate="0"),
    )

    for column in payload.columns:
        assert column.est_tax.amount == Decimal(0)
        assert column.net_after_tax.amount == column.realized_pl.amount


def test_a_rate_above_the_bound_is_refused() -> None:
    """AC-1 — the bound is the option's own error, so both callers get a 422."""
    with pytest.raises(ValidationError, match="must not exceed"):
        ScenarioComparisonOptions(short_term_rate=str(MAX_RATE + Decimal("0.01")))


def test_a_rate_that_is_not_a_rate_is_refused() -> None:
    """AC-1 — the pattern admits a fraction of one, never a percentage."""
    with pytest.raises(ValidationError):
        ScenarioComparisonOptions(short_term_rate="35")


def test_the_lot_counts_are_readable_by_the_client(portfolio: Portfolio) -> None:
    """Spec 0050 OD-6 — they were `int`, which `ViewPayload` cannot read.

    Six readers, none for a JSON number. These two were published as though a
    client could bind them and it could not; they travel as decimal strings
    now, like every other number on this contract.
    """
    payload = render(portfolio, ScenarioComparisonOptions())

    for column in payload.columns:
        assert isinstance(column.short_term_lots, str)
        assert isinstance(column.long_term_lots, str)
        assert column.short_term_lots.isdigit()
