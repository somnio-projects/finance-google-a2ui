"""Spec 0051 — the winner, the recommendation and the footer sentence.

The winner is the one thing on this card that can be **individually correct
and collectively wrong**: every figure right, the tick on the wrong column. So
it is asserted as a **relationship over every row of every render** — the
marked column's figure is the best in its row under that row's direction —
and never as a literal per row.
"""

from decimal import Decimal

import pytest

from app.domain.portfolio import Portfolio
from app.presentation.displays import MoneyDisplay
from app.presentation.scenario_columns import ScenarioColumn
from app.presentation.scenario_rows import HIGHER
from app.presentation.scenario_verdict import BEST_RESULT, LEVEL
from app.presentation.views.scenario_comparison import (
    ScenarioComparisonOptions,
    render,
)


def _amount(column: ScenarioColumn, key: str) -> Decimal:
    """The exact figure ``key`` names on a rendered column."""
    figure: MoneyDisplay = getattr(column, key)
    return figure.amount


@pytest.mark.parametrize("include_wait", [False, True])
def test_every_marked_cell_is_the_best_one_in_its_row(
    portfolio: Portfolio, include_wait: bool
) -> None:
    """AC-2 — the relationship, over both artboards the frame draws."""
    payload = render(portfolio, ScenarioComparisonOptions(include_wait=include_wait))

    assert payload.rows
    for row in payload.rows:
        amounts = [_amount(column, row.key) for column in payload.columns]
        best = max(amounts) if row.direction_label == HIGHER else min(amounts)
        if row.winner is None:
            # A tie names nobody — and it must really be a tie.
            assert amounts.count(best) > 1
            continue
        marked = next(c for c in payload.columns if c.key == row.winner)
        assert _amount(marked, row.key) == best
        assert amounts.count(best) == 1


def test_proceeds_ties_in_every_column(portfolio: Portfolio) -> None:
    """AC-2 — the card's premise: one sale, so that row can never have a winner."""
    payload = render(portfolio, ScenarioComparisonOptions())
    row = next(row for row in payload.rows if row.key == "proceeds")

    assert row.winner is None
    assert len({_amount(c, "proceeds") for c in payload.columns}) == 1


def test_the_recommendation_is_the_after_tax_winner_and_nothing_else(
    portfolio: Portfolio,
) -> None:
    """AC-2 — one claim, one source: two derivations would drift apart."""
    payload = render(portfolio, ScenarioComparisonOptions(include_wait=True))
    net = next(row for row in payload.rows if row.key == "net_after_tax")
    tagged = [column for column in payload.columns if column.recommended]

    assert [column.key for column in tagged] == ([net.winner] if net.winner else [])
    for column in tagged:
        assert column.recommendation_label is not None


def test_a_summary_that_names_a_winner_never_claims_a_tie(
    portfolio: Portfolio,
) -> None:
    """AC-2 — the first render said both at once, which is what this catches.

    It marked FIFO `recommended` and printed *"every scenario leaves the same
    after tax"* beside it, because the sentence treated *the baseline won* as
    *nobody won*.
    """
    payload = render(portfolio, ScenarioComparisonOptions())
    winner = any(column.recommended for column in payload.columns)

    assert payload.summary.badge == BEST_RESULT
    assert (payload.summary.text == LEVEL) is not winner


def test_waiting_is_a_timing_column_not_a_fourth_method(
    portfolio: Portfolio,
) -> None:
    """AC-3 — `method`'s enum still means exactly one thing."""
    payload = render(portfolio, ScenarioComparisonOptions(include_wait=True))
    waiting = payload.columns[-1]

    assert waiting.kind == "timing"
    assert [c.kind for c in payload.columns[:-1]] == ["lot_method"] * (
        len(payload.columns) - 1
    )
    assert len({c.key for c in payload.columns}) == len(payload.columns)


def test_waiting_moves_the_tax_and_leaves_the_result(
    portfolio: Portfolio,
) -> None:
    """AC-3 — the column's claim: same sale, later, so only the term changes."""
    payload = render(portfolio, ScenarioComparisonOptions(include_wait=True))
    base, waiting = payload.columns[0], payload.columns[-1]

    assert _amount(waiting, "realized_pl") == _amount(base, "realized_pl")
    assert _amount(waiting, "proceeds") == _amount(base, "proceeds")
    assert _amount(waiting, "short_term_pl") == Decimal(0)
    assert _amount(waiting, "est_tax") <= _amount(base, "est_tax")
